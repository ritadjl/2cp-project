from django.conf import settings
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Conversation, Message, UserDevice
from .serializers import ConversationSerializer, MessageSerializer
from django.db.models import Q
from drf_spectacular.utils import extend_schema
import redis.asyncio as aioredis
from asgiref.sync import async_to_sync
from django.contrib.auth import get_user_model

User = get_user_model()


class StartConversationView(APIView):
    def post(self, request):
        print(f"DEBUG start conv: {request.data}")

        seller_id = request.data.get('seller_id')
        announcement_id = request.data.get('announcement_id')  # ← was 'listing'
        buyer = request.user

        if not seller_id:
            return Response({'error': 'seller_id required'}, status=status.HTTP_400_BAD_REQUEST)

        if str(buyer.id) == str(seller_id):
            return Response({'error': 'Cannot start a conversation with yourself'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            seller = User.objects.get(id=seller_id)
        except (User.DoesNotExist, ValueError):
            return Response({'error': 'Seller not found'}, status=status.HTTP_404_NOT_FOUND)

        conversation, created = Conversation.objects.get_or_create(
            buyer=buyer,
            seller=seller,
            announcement_id=announcement_id  # ← was listing=listing
        )

        out = ConversationSerializer(conversation)
        return Response(
            out.data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
        )


class ConversationListView(APIView):
    def get(self, request):
        user = request.user
        conversations = Conversation.objects.filter(
            Q(buyer=user, is_deleted_by_buyer=False) |
            Q(seller=user, is_deleted_by_seller=False)
        ).order_by('-created_at')
        serializer = ConversationSerializer(
            conversations,
            many=True,
            context={'request': request}  # ← ADD THIS
        )
        return Response(serializer.data)

class MessageListView(APIView):
    def get(self, request, conversation_id):
        try:
            conversation = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        if request.user != conversation.buyer and request.user != conversation.seller:
            return Response(status=status.HTTP_403_FORBIDDEN)

        messages = Message.objects.filter(
            conversation=conversation
        ).order_by('timestamp')

        serializer = MessageSerializer(messages, many=True)
        return Response(serializer.data)


class MarkAsReadView(APIView):
    def patch(self, request, conversation_id):
        try:
            conversation = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        if request.user != conversation.buyer and request.user != conversation.seller:
            return Response(status=status.HTTP_403_FORBIDDEN)

        Message.objects.filter(
            conversation=conversation,
            is_read=False
        ).exclude(
            sender=request.user
        ).update(is_read=True)

        return Response(status=status.HTTP_200_OK)


class UnreadCountView(APIView):
    def get(self, request):
        count = Message.objects.filter(
            Q(conversation__buyer=request.user) | Q(conversation__seller=request.user),
            is_read=False,
        ).exclude(sender=request.user).count()
        return Response({'unread_count': count})


class UserStatusView(APIView):
    def get(self, request, user_id):
        async def check_status():
            r = aioredis.from_url(settings.REDIS_URL)
            result = await r.get(f"user_{user_id}_online")
            await r.aclose()
            return result

        result = async_to_sync(check_status)()
        is_online = result is not None
        return Response({'user_id': user_id, 'is_online': is_online})


class SaveDeviceTokenView(APIView):
    def post(self, request):
        token = request.data.get('device_token')
        if not token:
            return Response(
                {'error': 'device_token required'},
                status=status.HTTP_400_BAD_REQUEST
            )
        UserDevice.objects.update_or_create(
            user=request.user,
            defaults={'device_token': token}
        )
        return Response({'success': True})
    
class DeleteConversationView(APIView):
    def delete(self, request, conversation_id):
        try:
            conversation = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        if request.user == conversation.buyer:
            conversation.is_deleted_by_buyer = True
        elif request.user == conversation.seller:
            conversation.is_deleted_by_seller = True
        else:
            return Response(status=status.HTTP_403_FORBIDDEN)

        conversation.save()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
class DeleteMessageView(APIView):
    def delete(self, request, conversation_id, message_id):
        try:
            conversation = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        if request.user != conversation.buyer and request.user != conversation.seller:
            return Response(status=status.HTTP_403_FORBIDDEN)

        try:
            message = Message.objects.get(id=message_id, conversation=conversation)
        except Message.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        if message.sender != request.user:
            return Response(
                {'error': 'You can only delete your own messages'},
                status=status.HTTP_403_FORBIDDEN
            )

        message.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
class SendImageMessageView(APIView):
    def post(self, request, conversation_id):
        try:
            conversation = Conversation.objects.get(id=conversation_id)
        except Conversation.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)

        if request.user != conversation.buyer and request.user != conversation.seller:
            return Response(status=status.HTTP_403_FORBIDDEN)

        image = request.FILES.get('image')
        if not image:
            return Response({'error': 'image required'}, status=status.HTTP_400_BAD_REQUEST)

        msg = Message.objects.create(
            conversation=conversation,
            sender=request.user,
            content='',
            image=image
        )

        return Response({
            'id': str(msg.id),
            'image_url': request.build_absolute_uri(msg.image.url),
            'timestamp': str(msg.timestamp),
        }, status=status.HTTP_201_CREATED)