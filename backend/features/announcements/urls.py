from django.urls import path
from . import views

urlpatterns = [
    # category
    path('categories/', views.CategoryListAPIView.as_view(), name='category-list'),
    
    # university
    path('universities/', views.UniversityListAPIView.as_view(), name='university-list'),
    
    # announcements - read
    path('announcements/', views.AnnouncementListAPIView.as_view(), name='announcement-list'),
    
     #debug
    path('debug/seller-photo/', views.DebugSellerPhotoView.as_view(), name='debug-seller-photo'),

    # announcements - write (requires auth)
    path('announcements/my/', views.MyAnnouncementsAPIView.as_view(), name='my-announcements'),
    path('announcements/create/', views.AnnouncementCreateAPIView.as_view(), name='announcement-create'), 
    path('announcements/nearby/', views.NearbyAnnouncementsAPIView.as_view(), name='announcements-nearby'), 
    path('announcements/<int:pk>/', views.AnnouncementDetailAPIView.as_view(), name='announcement-detail'),
    path('announcements/<int:pk>/update/', views.AnnouncementUpdateAPIView.as_view(), name='announcement-update'),
    path('announcements/<int:pk>/archive/', views.AnnouncementArchiveAPIView.as_view(), name='announcement-archive'),
    path('announcements/<int:pk>/status/', views.AnnouncementStatusUpdateAPIView.as_view(), name='announcement-status'),
    
    # favorites
    path('favorites/', views.FavoriteListCreateAPIView.as_view(), name='favorite-list'),
    path('favorites/check/', views.CheckFavoritesAPIView.as_view(), name='favorite-check'),
    path('favorites/<int:pk>/', views.FavoriteDestroyAPIView.as_view(), name='favorite-detail'),
    
    # reviews
    path('announcements/<int:announcement_id>/reviews/', views.ReviewListCreateAPIView.as_view(), name='review-list'),
    path('reviews/<int:pk>/', views.ReviewUpdateDeleteAPIView.as_view(), name='review-detail'),
    
    # comments
    path('announcements/<int:announcement_id>/comments/', views.CommentListCreateAPIView.as_view(), name='comment-list'),
    path('comments/<int:pk>/', views.CommentUpdateDeleteAPIView.as_view(), name='comment-detail'),

    # reports
    path('reports/', views.ReportCreateAPIView.as_view(), name='report-create'),
    path('reports/list/', views.ReportListAPIView.as_view(), name='report-list'),

   
]

