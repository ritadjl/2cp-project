from django.urls import path
from . import views

urlpatterns = [
    path('conversations/', views.ConversationListView.as_view()),
    path('conversations/start/', views.StartConversationView.as_view()),
    path('conversations/unread-count/', views.UnreadCountView.as_view()),
    path('conversations/<int:conversation_id>/messages/', views.MessageListView.as_view()),
    path('conversations/<int:conversation_id>/read/', views.MarkAsReadView.as_view()),
    # ── ADD THIS LINE ───────────────────────────────────────────────────
    path('conversations/<int:conversation_id>/delete/', views.DeleteConversationView.as_view()),
    path('conversations/<int:conversation_id>/messages/<int:message_id>/delete/', views.DeleteMessageView.as_view()),
    path('conversations/<int:conversation_id>/messages/image/', views.SendImageMessageView.as_view()),
    # ────────────────────────────────────────────────────────────────────
    path('users/<str:user_id>/status/', views.UserStatusView.as_view()),
    path('devices/token/', views.SaveDeviceTokenView.as_view()),
]

