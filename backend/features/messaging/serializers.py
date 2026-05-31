from rest_framework import serializers
from features.announcements.models import Announcement
from features.announcements.serializers import AnnouncementListSerializer
from .models import Conversation, Message
from django.contrib.auth import get_user_model
import redis
from django.conf import settings
User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    avatar = serializers.SerializerMethodField()

    def get_avatar(self, obj):
        try:
            profile_picture = obj.student_profile.profile_picture
            if profile_picture:
                request = self.context.get('request')
                if request:
                    return request.build_absolute_uri(profile_picture.url)
                return profile_picture.url
        except Exception:
            return None

    class Meta:
        model = User
        fields = ['id', 'email', 'full_name', 'avatar']


class MessageSerializer(serializers.ModelSerializer):
    sender = UserSerializer(read_only=True)
    reply_to = serializers.SerializerMethodField()

    def get_reply_to(self, obj):
        if obj.reply_to:
            return {
                'id': str(obj.reply_to.id),
                'content': obj.reply_to.content,
                'sender_name': obj.reply_to.sender.full_name,
            }
        return None

    class Meta:
        model = Message
        fields = ['id', 'sender', 'content', 'timestamp', 'is_read', 'reply_to']


class ConversationSerializer(serializers.ModelSerializer):
    buyer = UserSerializer(read_only=True)
    seller = UserSerializer(read_only=True)
    announcement = AnnouncementListSerializer(read_only=True)
    announcement_id = serializers.PrimaryKeyRelatedField(
        queryset=Announcement.objects.all(),
        write_only=True,
        source='announcement'
    )
    last_message = serializers.SerializerMethodField()
    last_message_time = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()
    is_online = serializers.SerializerMethodField()

    def get_is_online(self, obj):
        request = self.context.get('request')
        if request is None:
            return False
        current_user = request.user
        other_user = obj.buyer if current_user == obj.seller else obj.seller
        try:
            r = redis.from_url(settings.REDIS_URL)
            result = r.get(f"user_{other_user.id}_online")
            r.close()
            return result is not None
        except Exception:
            return False

    def get_last_message(self, obj):
        msg = obj.messages.order_by('-timestamp').first()
        return msg.content if msg else ''

    def get_last_message_time(self, obj):
        msg = obj.messages.order_by('-timestamp').first()
        return msg.timestamp.isoformat() if msg else None

    def get_unread_count(self, obj):
        request = self.context.get('request')
        if not request:
            return 0
        return obj.messages.filter(is_read=False).exclude(sender=request.user).count()

    class Meta:
        model = Conversation
        fields = [
            'id', 'buyer', 'seller', 'announcement', 'announcement_id',
            'created_at', 'last_message', 'last_message_time', 'unread_count', 'is_online'
        ]

class StartConversationSerializer(serializers.Serializer):
    seller_id = serializers.CharField()
    announcement_id = serializers.IntegerField()