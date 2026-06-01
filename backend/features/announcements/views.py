from rest_framework import generics, status, pagination
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticatedOrReadOnly, IsAuthenticated
from rest_framework.parsers import MultiPartParser, FormParser
from django.db.models import Prefetch, Count, F, Q
from django.utils import timezone
from django.utils.decorators import method_decorator
from django.views.decorators.cache import cache_page
from django.views.decorators.vary import vary_on_headers
from .models import Announcement, Category, Photo, Favorite, Review, Comment, Report
from features.universities.models import University
from .serializers import (
    CategorySerializer,
    AnnouncementListSerializer,
    AnnouncementDetailSerializer,
    AnnouncementCreateSerializer,
    FavoriteSerializer,
    UniversitySerializer,
    ReviewSerializer,
    CommentSerializer,
    MyAnnouncementSerializer,
    ReportSerializer,
)
from features.notifications.signals import (
    notify_new_favorite,
    notify_new_review,
    notify_new_comment,
    notify_comment_reply,
)
import math


class CustomPagination(pagination.PageNumberPagination):
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

    def get_paginated_response(self, data):
        return Response({
            'results': data,
            'count': self.page.paginator.count,
            'next': self.get_next_link(),
            'previous': self.get_previous_link()
        })


class CategoryListAPIView(generics.ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer
    permission_classes = [IsAuthenticatedOrReadOnly]

    @method_decorator(cache_page(60 * 60))
    @method_decorator(vary_on_headers("Authorization",))
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class AnnouncementListAPIView(generics.ListAPIView):
    serializer_class = AnnouncementListSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]
    pagination_class = CustomPagination

    def get_queryset(self):
        queryset = Announcement.objects.filter(
            status=Announcement.Status.ACTIVE
        ).select_related(
            'category',
            'university'
        ).prefetch_related(
            Prefetch('photos', queryset=Photo.objects.order_by('position'), to_attr='prefetched_photos')
        ).order_by('-created_at')

        category_id = self.request.query_params.get('category')
        if category_id and category_id.isdigit():
            queryset = queryset.filter(category_id=int(category_id))

        university_id = self.request.query_params.get('university')
        if university_id:
            queryset = queryset.filter(university_id=university_id)

        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(title__icontains=search)

        min_price = self.request.query_params.get('min_price')
        if min_price and min_price.replace('.', '', 1).isdigit():
            queryset = queryset.filter(price__gte=float(min_price))

        max_price = self.request.query_params.get('max_price')
        if max_price and max_price.replace('.', '', 1).isdigit():
            queryset = queryset.filter(price__lte=float(max_price))

        student_id = self.request.query_params.get('student_id')
        if student_id:
            queryset = queryset.filter(student_id=student_id)

        return queryset

    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


def calculate_distance(lat1, lon1, lat2, lon2):
    """Calculate distance in km between two coordinates"""
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon/2)**2
    return R * 2 * math.asin(math.sqrt(a))


class NearbyAnnouncementsAPIView(generics.ListAPIView):
    serializer_class = AnnouncementListSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]
    pagination_class = CustomPagination

    def get_queryset(self):
        lat = self.request.query_params.get('lat')
        lon = self.request.query_params.get('lon')

        try:
            lat = float(lat)
            lon = float(lon)
            radius = float(self.request.query_params.get('radius', 50))
        except (TypeError, ValueError):
            return Announcement.objects.none()

        nearby_university_ids = []
        for uni in University.objects.filter(
            latitude__isnull=False,
            longitude__isnull=False
        ):
            distance = calculate_distance(lat, lon, uni.latitude, uni.longitude)
            if distance <= radius:
                nearby_university_ids.append(uni.id)

        return Announcement.objects.filter(
            status=Announcement.Status.ACTIVE,
            university_id__in=nearby_university_ids
        ).select_related(
            'category', 'university'
        ).prefetch_related(
            Prefetch('photos', queryset=Photo.objects.order_by('position'), to_attr='prefetched_photos')
        ).order_by('-created_at')


class AnnouncementCreateAPIView(generics.CreateAPIView):
    serializer_class = AnnouncementCreateSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={'request': request})

        if serializer.is_valid():
            self.perform_create(serializer)

            announcement = serializer.instance
            photos_data = []

            for photo in announcement.photos.all().order_by('position'):
                photos_data.append({
                    'url': request.build_absolute_uri(photo.image.url)
                })

            response_data = {
                'id': announcement.id,
                'title': announcement.title,
                'price': float(announcement.price),
                'photos': photos_data,
                'created_at': announcement.created_at.isoformat()
            }

            return Response(response_data, status=status.HTTP_201_CREATED)
        else:
            return Response(
                {'errors': serializer.errors},
                status=status.HTTP_400_BAD_REQUEST
            )

    def perform_create(self, serializer):
        serializer.save()


class AnnouncementDetailAPIView(generics.RetrieveAPIView):
    serializer_class = AnnouncementDetailSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        if self.request.user.is_authenticated:
            return Announcement.objects.filter(
                Q(status=Announcement.Status.ACTIVE) | Q(student_id=self.request.user.id)
            )
        return Announcement.objects.filter(status=Announcement.Status.ACTIVE)

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        Announcement.objects.filter(pk=instance.pk).update(
            views_count=F('views_count') + 1
        )
        instance.views_count += 1
        serializer = self.get_serializer(instance)
        return Response(serializer.data)


class FavoriteListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = FavoriteSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Favorite.objects.filter(
            user_id=self.request.user.id
        ).select_related(
            'announcement__category',
            'announcement__university'
        ).prefetch_related(
            Prefetch('announcement__photos', queryset=Photo.objects.order_by('position'), to_attr='prefetched_photos')
        )

    def perform_create(self, serializer):
        favorite = serializer.save(user_id=self.request.user.id)
        announcement = favorite.announcement
        if announcement.student_id != self.request.user.id:
            notify_new_favorite(
                request=self.request,
                recipient_id=announcement.student_id,
                announcement_id=announcement.id,
                announcement_title=announcement.title,
            )


class FavoriteDestroyAPIView(generics.DestroyAPIView):
    """remove from favorites"""
    permission_classes = [IsAuthenticated]
    lookup_field = 'pk'

    def get_queryset(self):
        return Favorite.objects.filter(user_id=self.request.user.id)


class CheckFavoritesAPIView(generics.GenericAPIView):
    """Check which announcements are favorited"""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        announcement_ids = request.data.get('announcement_ids', [])
        if not announcement_ids:
            return Response({'favorited_ids': []})

        favorites = Favorite.objects.filter(
            user_id=request.user.id,
            announcement_id__in=announcement_ids
        ).values_list('announcement_id', flat=True)

        return Response({
            'favorited_ids': list(favorites)
        })


class UniversityListAPIView(generics.ListAPIView):
    queryset = University.objects.all()
    serializer_class = UniversitySerializer
    permission_classes = [IsAuthenticatedOrReadOnly]

    @method_decorator(cache_page(60 * 60 * 24))
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)


class MyAnnouncementsAPIView(generics.ListAPIView):
    serializer_class = MyAnnouncementSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = Announcement.objects.filter(student_id=self.request.user.id)
        print(f"DEBUG: user={self.request.user.id}, count={qs.count()}")
        return Announcement.objects.filter(
            student_id=self.request.user.id
        ).select_related(
            'category', 'university'
        ).prefetch_related(
            Prefetch('photos', queryset=Photo.objects.order_by('position'), to_attr='prefetched_photos')
        ).order_by('-created_at')


class AnnouncementUpdateAPIView(generics.UpdateAPIView):
    serializer_class = AnnouncementCreateSerializer
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def get_queryset(self):
        return Announcement.objects.filter(student_id=self.request.user.id)

    def get_serializer_class(self):
        return AnnouncementCreateSerializer

    def update(self, request, *args, **kwargs):
        instance = self.get_object()

        data = request.data.copy()

        serializer = AnnouncementCreateSerializer(
            instance,
            data=data,
            partial=True,
            context={'request': request}
        )
        serializer.is_valid(raise_exception=True)
        serializer.validated_data.pop('photos', None)
        serializer.save()

        photos = request.FILES.getlist('photos')
        if photos:
            instance.photos.all().delete()
            for position, photo_file in enumerate(photos, start=1):
                Photo.objects.create(
                    announcement=instance,
                    image=photo_file,
                    position=position
                )

        return Response(
            MyAnnouncementSerializer(instance, context={'request': request}).data,
            status=status.HTTP_200_OK
        )


class AnnouncementArchiveAPIView(generics.UpdateAPIView):
    serializer_class = AnnouncementCreateSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Announcement.objects.filter(student_id=self.request.user.id)

    def patch(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.status = Announcement.Status.ARCHIVED
        instance.save()
        return Response({'status': 'archived'})


class AnnouncementStatusUpdateAPIView(generics.UpdateAPIView):
    serializer_class = AnnouncementCreateSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Announcement.objects.filter(student_id=self.request.user.id)

    def patch(self, request, *args, **kwargs):
        instance = self.get_object()
        status_value = request.data.get('status')

        if status_value not in ['active', 'sold', 'expired', 'reserved']:
            return Response({'error': 'Invalid status'}, status=400)

        # ✅ ADDED: only increment when transitioning TO sold (prevents double counting)
        if status_value == 'sold' and instance.status != 'sold':
            try:
                profile = request.user.profile
                profile.completed_sales += 1
                profile.save()
            except Exception:
                pass  # don't block the status update if profile access fails

        instance.status = status_value
        instance.save()
        return Response({'status': status_value})


class ReviewListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        return Review.objects.filter(announcement_id=self.kwargs['announcement_id'])

    def perform_create(self, serializer):
        review = serializer.save(
            user_id=self.request.user.id,
            announcement_id=self.kwargs['announcement_id']
        )
        try:
            announcement = Announcement.objects.get(pk=self.kwargs['announcement_id'])
        except Announcement.DoesNotExist:
            return
        if announcement.student_id != self.request.user.id:
            notify_new_review(
                request=self.request,
                recipient_id=announcement.student_id,
                announcement_id=announcement.id,
                rating=review.rating,
            )


class ReviewUpdateDeleteAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = ReviewSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Review.objects.filter(user_id=self.request.user.id)


class CommentListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = CommentSerializer
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        return Comment.objects.filter(
            announcement_id=self.kwargs['announcement_id'],
            parent=None
        ).prefetch_related('replies')

    def perform_create(self, serializer):
        comment = serializer.save(
            user_id=self.request.user.id,
            announcement_id=self.kwargs['announcement_id']
        )
        try:
            announcement = Announcement.objects.get(pk=self.kwargs['announcement_id'])
        except Announcement.DoesNotExist:
            return

        if comment.parent:
            if comment.parent.user_id != self.request.user.id:
                notify_comment_reply(
                    request=self.request,
                    recipient_id=comment.parent.user_id,
                    announcement_id=announcement.id,
                    comment_id=comment.id,
                    reply_preview=comment.content,
                )
        else:
            if announcement.student_id != self.request.user.id:
                notify_new_comment(
                    request=self.request,
                    recipient_id=announcement.student_id,
                    announcement_id=announcement.id,
                    comment_id=comment.id,
                    comment_preview=comment.content,
                )


class CommentUpdateDeleteAPIView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = CommentSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Comment.objects.filter(user_id=self.request.user.id)


class ReportCreateAPIView(generics.CreateAPIView):
    serializer_class = ReportSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(reporter_id=self.request.user.id)


class ReportListAPIView(generics.ListAPIView):
    serializer_class = ReportSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Report.objects.filter(reporter_id=self.request.user.id)


class DebugSellerPhotoView(generics.GenericAPIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from features.authentication.models import Student
        a = Announcement.objects.get(id=1)
        s = Student.objects.filter(user_id=a.student_id).first()
        return Response({
            'student_id': str(a.student_id),
            'student_found': s is not None,
            'profile_picture': str(s.profile_picture) if s else None,
        })
