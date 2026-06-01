
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.utils.html import format_html
from .models import User, Student, EmailVerification
 
 
# ══════════════════════════════════════════════════════════════════
#  USER
# ══════════════════════════════════════════════════════════════════
@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display   = ('email', 'full_name', 'phone', 'role_badge', 'is_active_badge', 'created_at')
    list_filter    = ('is_active', 'is_staff', 'is_superuser')
    search_fields  = ('email', 'full_name', 'phone')
    ordering       = ('-created_at',)
 
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Informations personnelles', {'fields': ('full_name', 'phone')}),
        ('Permissions', {
            'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions'),
            'classes': ('collapse',),
        }),
        ('Dates', {'fields': ('created_at', 'last_login')}),
    )
    readonly_fields = ('created_at', 'last_login')
 
    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields':  ('email', 'full_name', 'password1', 'password2', 'is_active', 'is_staff'),
        }),
    )
 
    @admin.display(description='Rôle')
    def role_badge(self, obj):
        if obj.is_superuser:
            return format_html(
            '<span class="cm-badge cm-badge-admin">{}</span>', 'Superadmin'
        )
        if obj.is_staff:
            return format_html(
            '<span class="cm-badge cm-badge-spam">{}</span>', 'Staff'
            )
        return format_html(
        '<span class="cm-badge cm-badge-student">{}</span>', 'Student'
            )

    @admin.display(description='Statut')
    def is_active_badge(self, obj):
        if obj.is_active:
            return format_html(
            '<span class="cm-badge cm-badge-resolved">{}</span>', ' Actif'
        )
        return format_html(
        '<span class="cm-badge cm-badge-pending">{}</span>', 'Inactif'
        )
 
# ══════════════════════════════════════════════════════════════════
#  STUDENT
# ══════════════════════════════════════════════════════════════════
@admin.register(Student)
class StudentAdmin(admin.ModelAdmin):
    list_display  = ('avatar_preview', 'full_name', 'email_display', 'university', 'verified_badge', 'campus_location')
    list_filter   = ('verified', 'university')
    search_fields = ('user__full_name', 'user__email', 'student_id', 'campus_location')
    raw_id_fields = ('user',)
    ordering      = ('-user__created_at',)
 
    fieldsets = (
        ('Compte utilisateur', {'fields': ('user', 'university', 'student_id')}),
        ('Profil', {'fields': ('profile_picture', 'campus_location', 'description')}),
        ('Vérification', {'fields': ('verified',)}),
    )
 
    @admin.display(description='')
    def avatar_preview(self, obj):
        if obj.profile_picture:
            return format_html(
                '<img src="{}" height="34" width="34" '
                'style="border-radius:50%; object-fit:cover;"/>',
                obj.profile_picture.url
            )
        initials = obj.user.full_name[:1].upper() if obj.user.full_name else '?'
        return format_html(
            '<div style="width:34px; height:34px; border-radius:50%; '
            'background:#3076E0; color:#fff; display:flex; align-items:center; '
            'justify-content:center; font-size:13px; font-weight:600;">{}</div>',
            initials
        )
 
    @admin.display(description='Nom')
    def full_name(self, obj):
        return obj.user.full_name
 
    @admin.display(description='Email')
    def email_display(self, obj):
        return obj.user.email
 
    @admin.display(description='OTP Status')
    def verified_badge(self, obj):
        if obj.verified:
            return format_html('<span class="cm-badge cm-badge-resolved">Verified</span>')
        return format_html('<span class="cm-badge cm-badge-pending">Pending</span>')
 
 
# ══════════════════════════════════════════════════════════════════
#  EMAIL VERIFICATION
# ══════════════════════════════════════════════════════════════════
@admin.register(EmailVerification)
class EmailVerificationAdmin(admin.ModelAdmin):
    list_display  = ('user', 'purpose_badge', 'otp_status', 'created_at', 'expires_at')
    list_filter   = ('purpose', 'is_used')
    search_fields = ('user__email', 'user__full_name')
    ordering      = ('-created_at',)
    readonly_fields = ('user', 'code', 'purpose', 'created_at', 'expires_at', 'is_used')
 
    @admin.display(description='Type')
    def purpose_badge(self, obj):
        if obj.purpose == 'register':
            return format_html('<span class="cm-badge cm-badge-spam">Inscription</span>')
        return format_html('<span class="cm-badge cm-badge-pending">Reset MDP</span>')
 
    @admin.display(description='Statut OTP')
    def otp_status(self, obj):
        if obj.is_used:
            return format_html('<span class="cm-badge cm-badge-ignored">Utilisé</span>')
        if obj.is_valid():
            return format_html('<span class="cm-badge cm-badge-resolved">✓ Valide</span>')
        return format_html('<span class="cm-badge cm-badge-scam">Expiré</span>')
 
    def has_add_permission(self, request):
        return False