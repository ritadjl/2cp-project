import json
import asyncio
import redis.asyncio as aioredis
from channels.generic.websocket import AsyncWebsocketConsumer
from firebase_admin import messaging
from .models import Message, Conversation, UserDevice
from django.conf import settings
from features.notifications.utils import create_notification
from features.notifications.models import Notification

REDIS_URL = settings.REDIS_URL


def send_push_notification(token, title, body):
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=token,
        )
        messaging.send(message)
    except Exception as e:
        print(f"Notification error: {e}")


class ChatConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        if not self.scope["user"].is_authenticated:
            await self.close()
            return

        self.redis = aioredis.from_url(REDIS_URL)
        await self.redis.set(f"user_{self.scope['user'].id}_online", "true")

        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.room_group_name = f'chat_{self.conversation_id}'

        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'redis'):
            await self.redis.delete(f"user_{self.scope['user'].id}_online")
            await self.redis.aclose()

        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message = text_data_json['message']
        reply_to_id = text_data_json.get('reply_to_id')

        msg = await Message.objects.acreate(
            conversation_id=self.conversation_id,
            sender=self.scope['user'],
            content=message,
            reply_to_id=reply_to_id
        )

        payload = {
            "id": str(msg.id),
            "content": msg.content,
            "timestamp": str(msg.timestamp),
            "is_read": msg.is_read,
            "sender": {
                "email": self.scope['user'].email
            },
            "reply_to": {
                "id": str(msg.reply_to.id),
                "content": msg.reply_to.content,
                "sender_name": msg.reply_to.sender.full_name,
            } if msg.reply_to else None
        }

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                "type": "chat.message",
                "payload": payload
            }
        )

        await self.notify_receiver(message)

    async def chat_message(self, event):
        await self.send(text_data=json.dumps(event["payload"]))

    async def notify_receiver(self, message):
        try:
            conversation = await Conversation.objects.aget(
                id=self.conversation_id
            )
            sender = self.scope['user']

            receiver_id = conversation.seller_id if sender.id == conversation.buyer_id else conversation.buyer_id

            # ── Save notification to DB always ────────────────────────────
            await asyncio.to_thread(
                create_notification,
                user_id=receiver_id,
                notif_type=Notification.Type.NEW_MESSAGE,
                content=f"New message from {sender.full_name}",
                actor_id=sender.id,
                actor_full_name=sender.full_name,
                conversation_id=int(self.conversation_id),
                message_preview=message[:100],
            )

            # ── Always send Firebase push ─────────────────────────────────
            try:
                device = await UserDevice.objects.aget(user_id=receiver_id)
                await asyncio.to_thread(
                    send_push_notification,
                    device.device_token,
                    f"New message from {sender.full_name}",
                    message
                )
            except UserDevice.DoesNotExist:
                print("DEBUG: No device token found for receiver")

        except Exception as e:
            import traceback
            print(f"notify_receiver error: {e}")
            print(traceback.format_exc())