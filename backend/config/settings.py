from pathlib import Path
import environ
import dj_database_url
import os
import json
from datetime import timedelta
import firebase_admin
from firebase_admin import credentials

# ── Base ──────────────────────────────────────────────────────────────────────
BASE_DIR = Path(__file__).resolve().parent.parent

env = environ.Env()
environ.Env.read_env(os.path.join(BASE_DIR, '.env'))

SECRET_KEY = env('SECRET_KEY')
DEBUG = env.bool('DEBUG', default=False)  

ALLOWED_HOSTS = [
    '127.0.0.1', '10.0.2.2', 'localhost',
    'ritadjl.pythonanywhere.com',
    'twocp-project-mbil.onrender.com',
    'twocp-project-1-gtam.onrender.com',
]
CSRF_TRUSTED_ORIGINS = [
    'https://ritadjl.pythonanywhere.com',
    'https://twocp-project-1-gtam.onrender.com',
    'https://twocp-project-mbil.onrender.com',
]

# ── Applications ──────────────────────────────────────────────────────────────
INSTALLED_APPS = [
    'jazzmin',
    'daphne',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_extensions',
    # Third-party
    'crispy_forms',
    'crispy_bootstrap5',
    'rest_framework',
    'corsheaders',
    'channels',
    'drf_spectacular',
    'rest_framework_simplejwt.token_blacklist',
    'cloudinary',
    # Our apps
    'features.authentication',
    'features.universities',
    'features.announcements',
    'features.messaging',
    'features.moderation',
    'features.notifications',
    'features.accounts',
    'features.listings',
    'features.reviews',
    'features.deals',
]

# ══════════════════════════════════════════════════════════════════
#  JAZZMIN 
# ══════════════════════════════════════════════════════════════════

JAZZMIN_SETTINGS = {
    # ── Branding ─────────────────────────────────────────────────
    "site_title":   "Campus Market",
    "site_header":  "Campus Market",
    "site_brand":   "Campus Market",
    "site_logo":    "admin/logo.png",
    "site_logo_classes": "img-fluid",
    "site_icon":    "admin/logo.png",
    "welcome_sign": "Bienvenue sur Campus Market Admin",
    "copyright":    "Campus Market © 2025",

    # ── Recherche globale ─────────────────────────────────────────
    "search_model": [
        "authentication.User",
        "announcements.Announcement",
        "universities.University",
    ],

    # ── Liens top menu ────────────────────────────────────────────
    "topmenu_links": [
        {"name": "Dashboard", "url": "admin:index", "permissions": ["auth.view_user"]},
    ],

    # ── Menu utilisateur (avatar top-right) ───────────────────────
    "usermenu_links": [
        {
            "name":  "Mon profil",
            "url":   "/admin/",
            "icon":  "fas fa-user",
        },
    ],
    "user_avatar": None,

    # ── Sidebar ───────────────────────────────────────────────────
    "show_sidebar":         True,
    "navigation_expanded":  True,
    "hide_apps":  [],
    "hide_models": [],

    # Ordre des apps dans la sidebar (= ordre du mockup)
    "order_with_respect_to": [
        "authentication",
        "announcements",
        "universities",
        "listings",
        "deals",
        "reviews",
        "accounts",
        
    ],

    # ── Icônes (Font Awesome 5) ───────────────────────────────────
    "icons": {
        # Apps
        "authentication":            "fas fa-users",
        "announcements":             "fas fa-store",
        "universities":              "fas fa-university",
        "listings":                  "fas fa-shopping-bag",
        "deals":                     "fas fa-handshake",
        "reviews":                   "fas fa-star-half-alt",
        "accounts":                  "fas fa-id-card",
        

        # Modèles
        "authentication.User":             "fas fa-user",
        "authentication.Student":          "fas fa-user-graduate",
        "authentication.EmailVerification":"fas fa-envelope-open-text",

        "announcements.Announcement":  "fas fa-tag",
        "announcements.Category":      "fas fa-th-large",
        "announcements.Photo":         "fas fa-image",
        "announcements.Favorite":      "fas fa-heart",
        "announcements.Review":        "fas fa-star",
        "announcements.Comment":       "fas fa-comment",    
        "announcements.Report":        "fas fa-flag",

        "universities.University":     "fas fa-university",

        "listings.Listing":            "fas fa-shopping-bag",
        "deals.Deal":                  "fas fa-handshake",
        "reviews.Review":              "fas fa-star",
        "accounts.Profile":            "fas fa-id-card",
    },

    "default_icon_parents":  "fas fa-chevron-circle-right",
    "default_icon_children": "fas fa-circle",

    # ── CSS/JS custom ─────────────────────────────────────────────
    
    "custom_css": "admin/css/campusmarket.css",
    "custom_js":  None,

    # ── Divers ────────────────────────────────────────────────────
    "use_google_fonts_cdn":  False,   # pas de requête externe
    "show_ui_builder":       False,   # désactiver en prod
    "related_modal_active":  True,    # popups pour FK
    "changeform_format":     "horizontal_tabs",
    "hide_apps": [
        "messaging",
        "notifications",
    ],
}

JAZZMIN_UI_TWEAKS = {
    # Textes compacts
    "navbar_small_text":  False,
    "footer_small_text":  False,
    "body_small_text":    False,
    "brand_small_text":   False,

    "brand_colour":  False,               # ← CORRIGÉ : était "navbar-primary"
    "accent":        "accent-primary",
    "navbar":        "navbar-white navbar-light",  # ← navbar blanche

    # Layout
    "no_navbar_border": False,            # ← CORRIGÉ : était True (cachait la bordure)
    "navbar_fixed":     True,
    "layout_boxed":     False,
    "footer_fixed":     False,
    "sidebar_fixed":    True,

    
    "sidebar":                    "sidebar-primary",
    "sidebar_nav_small_text":     False,
    "sidebar_disable_expand":     False,
    "sidebar_nav_child_indent":   True,
    "sidebar_nav_compact_style":  False,
    "sidebar_nav_legacy_style":   False,
    "sidebar_nav_flat_style":     True,

    "theme":           "default",
    "dark_mode_theme": None,

    "button_classes": {
        "primary":   "btn-primary",
        "secondary": "btn-secondary",
        "info":      "btn-outline-info",
        "warning":   "btn-warning",
        "danger":    "btn-danger",
        "success":   "btn-success",
    },
}

AUTH_USER_MODEL = 'authentication.User'

CRISPY_ALLOWED_TEMPLATE_PACKS = 'bootstrap5'
CRISPY_TEMPLATE_PACK = 'bootstrap5'

# ── Redirections ──────────────────────────────────────────────────────────────
LOGIN_URL           = '/auth/login/'
LOGIN_REDIRECT_URL  = '/'
LOGOUT_REDIRECT_URL = '/admin/login/'   

# ── Middleware ────────────────────────────────────────────────────────────────
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'
ASGI_APPLICATION  = 'config.asgi.application'

# ── Database ──────────────────────────────────────────────────────────────────
# Local → SQLite | Prod → PostgreSQL via DATABASE_URL
DATABASE_URL = os.environ.get('DATABASE_URL')

if DATABASE_URL:
    DATABASES = {
        'default': dj_database_url.parse(DATABASE_URL, conn_max_age=600)
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }



# ── Storage ───────────────────────────────────────────────────────────────────
# Local → FileSystem | Prod → Cloudinary pour les médias
CLOUDINARY_STORAGE = {
    'CLOUD_NAME': env('CLOUDINARY_CLOUD_NAME', default=''),
    'API_KEY':    env('CLOUDINARY_API_KEY',    default=''),
    'API_SECRET': env('CLOUDINARY_API_SECRET', default=''),
}

STORAGES = {
    "default": {
        "BACKEND": (
            "django.core.files.storage.FileSystemStorage"
            if DEBUG else
            "cloudinary_storage.storage.MediaCloudinaryStorage"
        ),
    },
    "staticfiles": {
        "BACKEND": (
            "django.contrib.staticfiles.storage.StaticFilesStorage"
            if DEBUG else
            "whitenoise.storage.CompressedManifestStaticFilesStorage"
        ),
    },
}

MEDIA_URL  = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

# ── Static ────────────────────────────────────────────────────────────────────
STATIC_URL       = '/static/'
STATIC_ROOT      = BASE_DIR / 'staticfiles'
STATICFILES_DIRS = [BASE_DIR / 'static']


# ── Password validation ───────────────────────────────────────────────────────
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# ── i18n ──────────────────────────────────────────────────────────────────────
LANGUAGE_CODE = 'en-us'
TIME_ZONE     = 'UTC'
USE_I18N      = True
USE_TZ        = True

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ── Redis + Channels ──────────────────────────────────────────────────────────
REDIS_URL = env('REDIS_URL', default='redis://127.0.0.1:6379')

CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG":  {"hosts": [REDIS_URL]},
    },
}

# ── REST Framework ────────────────────────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_RENDERER_CLASSES': [
        'rest_framework.renderers.JSONRenderer',
    ],
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
}

CORS_ALLOW_ALL_ORIGINS = True

# ── Firebase ──────────────────────────────────────────────────────────────────
firebase_cred_path = os.path.join(BASE_DIR, 'firebase-credentials.json')
firebase_cred_json = env('FIREBASE_CREDENTIALS_JSON', default=None)

if not firebase_admin._apps:
    if firebase_cred_json:
        cred = credentials.Certificate(json.loads(firebase_cred_json))
        firebase_admin.initialize_app(cred)
    elif os.path.exists(firebase_cred_path):
        cred = credentials.Certificate(firebase_cred_path)
        firebase_admin.initialize_app(cred)

# ── Announcements ─────────────────────────────────────────────────────────────
MAX_PHOTOS_PER_ANNOUNCEMENT = 10
MAX_PHOTO_SIZE_MB            = 30
ALLOWED_IMAGE_EXTENSIONS     = ['.jpg', '.jpeg', '.png', '.gif']
ANNOUNCEMENTS_PER_PAGE       = 20

FILE_UPLOAD_MAX_MEMORY_SIZE  = 30 * 1024 * 1024   # 30 MB
DATA_UPLOAD_MAX_MEMORY_SIZE  = 30 * 1024 * 1024

# ── JWT ───────────────────────────────────────────────────────────────────────
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME':         timedelta(minutes=60),
    'REFRESH_TOKEN_LIFETIME':        timedelta(days=7),    # sans remember me
    'REFRESH_TOKEN_LIFETIME_LONG':   timedelta(days=30),   # avec remember me
}

# ── Email (Gmail SMTP) ────────────────────────────────────────────────────────
EMAIL_BACKEND       = env('EMAIL_BACKEND', default='django.core.mail.backends.smtp.EmailBackend')
EMAIL_HOST          = env('EMAIL_HOST', default='smtp.gmail.com')
EMAIL_PORT          = int(env('EMAIL_PORT', default='587'))
EMAIL_USE_TLS       = env('EMAIL_USE_TLS', default='True') == 'True'
EMAIL_HOST_USER     = env('EMAIL_HOST_USER', default='')
EMAIL_HOST_PASSWORD = env('EMAIL_HOST_PASSWORD', default='')
DEFAULT_FROM_EMAIL  = env('DEFAULT_FROM_EMAIL', default='')
RESEND_API_KEY = env('RESEND_API_KEY', default='')
BREVO_API_KEY = env('BREVO_API_KEY', default='')