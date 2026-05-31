from django.db import models
from django.conf import settings

class Conversation(models.Model):
    buyer = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='buyer_conversations'
    )
    seller = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='seller_conversations'
    )
    #listing = models.CharField(max_length=255)
    announcement = models.ForeignKey(          # ← replace listing
        'announcements.Announcement',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='conversations'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    # ── ADD THESE TWO LINES ──────────────────
    is_deleted_by_buyer = models.BooleanField(default=False)
    is_deleted_by_seller = models.BooleanField(default=False)
    # ────────────────────────────────────────

class Message(models.Model):
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE, 
        related_name='sent_messages'
    )
    content = models.TextField(blank=True)  # ← make blank=True (image messages may have no text)
    image = models.ImageField(upload_to='message_images/', null=True, blank=True)  # ← ADD THIS
    timestamp = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)
    reply_to = models.ForeignKey(  
        'self',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='replies'
     )# ← ADD THIS

class UserDevice(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, 
        on_delete=models.CASCADE
    )
    device_token = models.CharField(max_length=255)
    updated_at = models.DateTimeField(auto_now=True)

