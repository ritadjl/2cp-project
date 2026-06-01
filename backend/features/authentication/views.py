import os
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken
from features.universities.models import University
from .models import Student, EmailVerification
from .utils.email import send_verification_code
from google.oauth2 import id_token #added for google login
from google.auth.transport import requests as google_requests #

User = get_user_model()


# ─── Helpers ────────────────────────────────────────────────────────────────

def _issue_tokens(user):
    refresh = RefreshToken.for_user(user)
    return {'access': str(refresh.access_token), 'refresh': str(refresh)}


# ─── Université ──────────────────────────────────────────────────────────────

class UniversityListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        universities = University.objects.all().order_by('name')
        return Response([{'id': str(u.id), 'name': u.name} for u in universities])


# ─── Inscription ─────────────────────────────────────────────────────────────

class RegisterView(APIView):
    """
    Étape 1 : crée le compte (inactif) et envoie le code de confirmation.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        email         = request.data.get('email')
        password      = request.data.get('password')
        full_name     = request.data.get('full_name')
        phone         = request.data.get('phone') or request.data.get('phone_number')
        university_id = request.data.get('university_id', None)

        if not email or not password or not full_name:
            return Response(
                {'error': 'email, password et full_name sont obligatoires'},
                status=400
            )

        # Cas : email déjà utilisé par un compte actif
        existing = User.objects.filter(email=email).first()
        if existing:
            if existing.is_active:
                return Response({'error': 'Email déjà utilisé'}, status=400)
            # Compte inactif (inscription non confirmée) → on réenvoie un code
            verification = EmailVerification.generate_for(existing, EmailVerification.PURPOSE_REGISTER)
            send_verification_code(email, verification.code, 'register')
            return Response(
                {'message': 'Compte déjà existant mais non confirmé. Nouveau code envoyé.'},
                status=200
            )

        university = None
        if university_id:
            try:
                university = University.objects.get(id=university_id)
            except University.DoesNotExist:
                return Response({'error': 'Université introuvable'}, status=400)

        user = User.objects.create_user(
            email=email,
            password=password,
            full_name=full_name,
            phone=phone,
        )  # is_active=False par défaut

        Student.objects.create(user=user, university=university)

        verification = EmailVerification.generate_for(user, EmailVerification.PURPOSE_REGISTER)
        send_verification_code(email, verification.code, 'register')

        return Response(
            {'message': 'Compte créé. Vérifie ton email pour confirmer ton inscription.'},
            status=201
        )


class VerifyEmailView(APIView):
    """
    Étape 2 : valide le code → active le compte → retourne les tokens JWT.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email')
        code  = request.data.get('code')

        if not email or not code:
            return Response({'error': 'email et code sont obligatoires'}, status=400)

        try:
            user = User.objects.get(email=email)
        except User.DoesNotExist:
            return Response({'error': 'Utilisateur introuvable'}, status=404)

        verification = (
            EmailVerification.objects
            .filter(user=user, purpose=EmailVerification.PURPOSE_REGISTER, is_used=False)
            .order_by('-created_at')
            .first()
        )

        if not verification or not verification.is_valid():
            return Response({'error': 'Code expiré ou invalide'}, status=400)

        if verification.code != code:
            return Response({'error': 'Code incorrect'}, status=400)

        # Activer le compte
        verification.is_used = True
        verification.save()
        user.is_active = True
        user.save()

        if hasattr(user, 'student_profile'):
            user.student_profile.verified = True
            user.student_profile.save()

        return Response(_issue_tokens(user), status=200)


class ResendVerificationCodeView(APIView):
    """
    Renvoie un code de confirmation pour un compte non encore activé.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({'error': 'email est obligatoire'}, status=400)

        try:
            user = User.objects.get(email=email, is_active=False)
        except User.DoesNotExist:
            # On ne précise pas si l'email existe ou non (sécurité)
            return Response({'message': 'Si ce compte existe, un code a été envoyé.'}, status=200)

        verification = EmailVerification.generate_for(user, EmailVerification.PURPOSE_REGISTER)
        send_verification_code(email, verification.code, 'register')
        return Response({'message': 'Nouveau code envoyé.'}, status=200)


# ─── Mot de passe oublié ─────────────────────────────────────────────────────

class ForgotPasswordView(APIView):
    """
    Étape 1 : envoie un code de réinitialisation.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email')
        if not email:
            return Response({'error': 'email est obligatoire'}, status=400)

        try:
            user = User.objects.get(email=email, is_active=True)
        except User.DoesNotExist:
            return Response({'message': 'Si ce compte existe, un code a été envoyé.'}, status=200)

        verification = EmailVerification.generate_for(user, EmailVerification.PURPOSE_RESET_PASSWORD)
        send_verification_code(email, verification.code, 'reset_password')
        return Response({'message': 'Code de réinitialisation envoyé.'}, status=200)


class ResetPasswordView(APIView):
    """
    Étape 2 : valide le code et change le mot de passe.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        email        = request.data.get('email')
        code         = request.data.get('code')
        new_password = request.data.get('new_password')

        if not email or not code or not new_password:
            return Response(
                {'error': 'email, code et new_password sont obligatoires'},
                status=400
            )

        if len(new_password) < 8:
            return Response({'error': 'Le mot de passe doit contenir au moins 8 caractères'}, status=400)

        try:
            user = User.objects.get(email=email, is_active=True)
        except User.DoesNotExist:
            return Response({'error': 'Utilisateur introuvable'}, status=404)

        verification = (
            EmailVerification.objects
            .filter(user=user, purpose=EmailVerification.PURPOSE_RESET_PASSWORD, is_used=False)
            .order_by('-created_at')
            .first()
        )

        if not verification or not verification.is_valid():
            return Response({'error': 'Code expiré ou invalide'}, status=400)

        if verification.code != code:
            return Response({'error': 'Code incorrect'}, status=400)

        verification.is_used = True
        verification.save()

        user.set_password(new_password)
        user.save()

        return Response({'message': 'Mot de passe réinitialisé avec succès.'}, status=200)


# ─── Profil ──────────────────────────────────────────────────────────────────

class UpdateProfilePictureView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if not hasattr(request.user, 'student_profile'):
            return Response({'error': 'Profil étudiant introuvable'}, status=400)

        student = request.user.student_profile

        if 'profile_picture' not in request.FILES:
            return Response({'error': 'Aucune image envoyée'}, status=400)

        student.profile_picture = request.FILES['profile_picture']
        student.save()

        return Response({
            'message':         'Photo mise à jour avec succès',
            'profile_picture': request.build_absolute_uri(student.profile_picture.url),
        })


class UpdateProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def put(self, request):
        user = request.user

        full_name = request.data.get('full_name')
        phone     = request.data.get('phone')

        if full_name:
            user.full_name = full_name
        if phone:
            user.phone = phone
        user.save()

        if hasattr(user, 'student_profile'):
            student       = user.student_profile
            university_id = request.data.get('university_id')
            campus        = request.data.get('campus_location')
            description   = request.data.get('description')

            if university_id:
                try:
                    student.university = University.objects.get(id=university_id)
                except University.DoesNotExist:
                    return Response({'error': 'Université introuvable'}, status=400)

            if campus:
                student.campus_location = campus
            if description:
                student.description = description

            student.save()

        return Response({
            'message':    'Profil mis à jour avec succès',
            'id':         str(user.id),
            'email':      user.email,
            'full_name':  user.full_name,
            'phone':      user.phone,
            'university': {
                'id':   str(student.university.id),
                'name': student.university.name,
            } if hasattr(user, 'student_profile') and student.university else None,
        })


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        try:
            token = RefreshToken(request.data.get('refresh'))
            token.blacklist()
            return Response({'message': 'Déconnecté'})
        except Exception:
            return Response({'error': 'Token invalide'}, status=400)

class UserProfileView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        data = {
            'id':        str(user.id),
            'email':     user.email,
            'full_name': user.full_name,
            'phone':     user.phone,
        }

        if hasattr(user, 'student_profile'):
            student = user.student_profile
            data['university'] = (
                {'id': str(student.university.id), 'name': student.university.name}
                if student.university else None
            )
            data['profile_picture'] = (
                request.build_absolute_uri(student.profile_picture.url)
                if student.profile_picture else None
            )

        return Response(data)


class LoginView(APIView):  
    permission_classes = [AllowAny]

    def post(self, request):

        email       = request.data.get('email')
        password    = request.data.get('password')
        remember_me = request.data.get('remember_me', False)

        if not email or not password:
            return Response({
                'access':  str(refresh.access_token),
                'refresh': str(refresh),
                'user': {
                          'id':        str(user.id),
                          'email':     user.email,
                        'full_name': user.full_name,
                          }
                                    })

        try:
            user = User.objects.get(email=email, is_active=True)
        except User.DoesNotExist:
            return Response({'error': 'Identifiants invalides'}, status=401)

        if not user.check_password(password):
            return Response({'error': 'Identifiants invalides'}, status=401)

        refresh = RefreshToken.for_user(user)

        if remember_me:
            from datetime import timedelta
            refresh.set_exp(lifetime=timedelta(days=30))

        return Response({
            'access':  str(refresh.access_token),
            'refresh': str(refresh),
        })
    
 # ─── Google OAuth ─────────────────────────────────────────────────────────────

class GoogleLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get('id_token')
        if not token:
            return Response({'error': 'id_token is required'}, status=400)

        ALLOWED_CLIENT_IDS = [
            os.environ.get('GOOGLE_CLIENT_ID'),
            os.environ.get('GOOGLE_ANDROID_CLIENT_ID'),
        ]

        idinfo = None
        for client_id in ALLOWED_CLIENT_IDS:
            try:
                idinfo = id_token.verify_oauth2_token(
                    token,
                    google_requests.Request(),
                    client_id
                )
                break
            except ValueError:
                continue

        if idinfo is None:
            return Response({'error': 'Invalid Google token'}, status=400)

        email     = idinfo.get('email')
        full_name = idinfo.get('name', '')

        if not email:
            return Response({'error': 'Could not get email from Google'}, status=400)

        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                'full_name': full_name,
                'is_active': True,
            }
        )

        if not created and not user.is_active:
            user.is_active = True
            user.save()

        if not hasattr(user, 'student_profile'):
            student = Student.objects.create(user=user, verified=True)
        else:
            student = user.student_profile

        # Ensure Profile exists (in case signal didn't fire)
        from features.accounts.models import Profile
        Profile.objects.get_or_create(student=student)

        return Response(_issue_tokens(user), status=200)
    
# ─── Apple OAuth ──────────────────────────────────────────────────────────────

class AppleLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        # Apple sends a 'code' or 'id_token' depending on the Flutter package
        apple_token = request.data.get('id_token')
        email       = request.data.get('email')      # Apple only sends email on FIRST login
        full_name   = request.data.get('full_name', '')

        if not apple_token and not email:
            return Response({'error': 'id_token or email is required'}, status=400)

        # For Apple, basic implementation: trust the email sent
        # (Full verification requires Apple's public keys — add later if needed)
        if not email:
            return Response({'error': 'Email not provided by Apple'}, status=400)

        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                'full_name': full_name or email.split('@')[0],
                'is_active': True,
            }
        )

        if not created and not user.is_active:
            user.is_active = True
            user.save()

        if not hasattr(user, 'student_profile'):
            Student.objects.create(user=user, verified=True)

        return Response(_issue_tokens(user), status=200)