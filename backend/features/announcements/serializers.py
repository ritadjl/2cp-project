from rest_framework import serializers
from django.db.models import Avg
from django.db import transaction
from django.core.files.images import get_image_dimensions
from .models import Announcement, Category, Photo, Favorite, Review, Comment, Report
from features.universities.models import University
from django.contrib.auth import get_user_model
User = get_user_model()


class CategorySerializer(serializers.ModelSerializer):

    class Meta:
        model = Category
        fields = ['id', 'name', 'description', 'icon']


class PhotoSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model = Photo
        fields = ['id', 'url', 'position']

    def get_url(self, obj):
        if obj.image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.image.url)  # full URL with domain
            return obj.image.url
        return None


class AnnouncementListSerializer(serializers.ModelSerializer):
    photo = serializers.SerializerMethodField()
    seller = serializers.CharField(source='student_full_name')
    seller_id = serializers.UUIDField(source='student_id')
    seller_photo = serializers.SerializerMethodField()
    category = serializers.CharField(source='category.name')
    university = serializers.CharField(source='university.name', read_only=True)
    price = serializers.DecimalField(max_digits=10, decimal_places=2, coerce_to_string=False)
    is_favorited = serializers.SerializerMethodField()

    class Meta:
        model = Announcement
        fields = [
            'id', 'title', 'price', 'photo',
            'seller', 'seller_id','seller_photo','category', 'created_at', 'university',
            'is_favorited'
        ]

    def get_is_favorited(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            favorited_by = getattr(obj, '_prefetched_objects_cache', {}).get('favorited_by')
            if favorited_by is not None:
                return any(f.user_id == request.user.id for f in favorited_by)
            return obj.favorited_by.filter(user_id=request.user.id).exists()
        return False

    def get_photo(self, obj):
       photos = getattr(obj, 'prefetched_photos', None) or obj.photos.all()
       first = photos[0] if photos else None
       if first and first.image:
           request = self.context.get('request')
           if request:
               return request.build_absolute_uri(first.image.url)  # ← full URL
           return first.image.url
       return None
    def get_seller_photo(self, obj):
        from features.authentication.models import Student
        student = Student.objects.filter(user_id=obj.student_id).first()
        if student is None:
            return "NO_STUDENT_FOUND"
        if not student.profile_picture:
            return "NO_PROFILE_PICTURE"
        request = self.context.get('request')
        return request.build_absolute_uri(student.profile_picture.url) if request else student.profile_picture.url
    
    


class AnnouncementDetailSerializer(serializers.ModelSerializer):
    photos = PhotoSerializer(many=True, read_only=True)
    seller = serializers.CharField(source='student_full_name')
    seller_id = serializers.UUIDField(source='student_id')
    seller_photo = serializers.SerializerMethodField()
    category = CategorySerializer(read_only=True)
    university = serializers.CharField(source='university.name', read_only=True)
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.all(),
        source='category',
        write_only=True
    )
    university_id = serializers.PrimaryKeyRelatedField(
        queryset=University.objects.all(),
        source='university',
        write_only=True,
        required=False,
        allow_null=True
    )
    price = serializers.DecimalField(max_digits=10, decimal_places=2, coerce_to_string=False)
    average_rating = serializers.SerializerMethodField()
    reviews_count = serializers.SerializerMethodField()
    comments_count = serializers.SerializerMethodField()

    class Meta:
        model = Announcement
        fields = [
            'id', 'title', 'description', 'price',
            'photos', 'seller', 'seller_id', 'seller_photo', 'category', 'university',
            'category_id', 'university_id', 'location',
            'phone_number', 'whatsapp', 'telegram', 'instagram',
            'facebook', 'allow_chat', 'condition', 'model','url',
            'status', 'created_at', 'updated_at',
            'views_count', 'average_rating', 'reviews_count', 'comments_count'
            ]
        read_only_fields = ['student_id', 'student_full_name', 'status', 'created_at', 'updated_at']

    def get_average_rating(self, obj):
        result = obj.reviews.aggregate(avg=Avg('rating'))
        return round(result['avg'], 2) if result['avg'] else 0

    def get_reviews_count(self, obj):
        return obj.reviews.count()

    def get_comments_count(self, obj):
        return obj.comments.count()
    def get_seller_photo(self, obj): 
        from features.authentication.models import Student
        try:
            student = Student.objects.get(user_id=obj.student_id)
            if student.profile_picture:
                request = self.context.get('request')
                return request.build_absolute_uri(student.profile_picture.url) if request else student.profile_picture.url
        except Student.DoesNotExist:
            pass
        return None


class AnnouncementCreateSerializer(serializers.ModelSerializer):
    photos = serializers.ListField(
        child=serializers.ImageField(
            max_length=100,
            allow_empty_file=False,
            use_url=False
        ),
        write_only=True,
        required=False,
        min_length=0,
        max_length=10
    )
    price = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=0)

    class Meta:
        model = Announcement
        fields = [
            'title', 'description', 'price',
            'category', 'location', 'university',
            'phone_number', 'whatsapp', 'telegram', 'instagram', 
            'facebook', 'allow_chat', 'condition','model', 'url',
            'photos'
            ]

    def validate_photos(self, value):
        if len(value) > 10:
            raise serializers.ValidationError("Maximum 10 photos allowed")

        for image in value:
            if image.size > 30 * 1024 * 1024:
                raise serializers.ValidationError(f"Image {image.name} is too large. Max size is 30MB")

            width, height = get_image_dimensions(image)
            if width > 4000 or height > 4000:
                raise serializers.ValidationError(f"Image {image.name} dimensions are too large")

        return value

    def validate_title(self, value):
        if not value or not value.strip():
            raise serializers.ValidationError("Title cannot be empty")
        return value.strip()

  

    def create(self, validated_data):
         photos_data = validated_data.pop('photos', [])
         request = self.context.get('request')

         with transaction.atomic():  
            announcement = Announcement.objects.create(
                student_id=request.user.id,
                student_full_name=request.user.full_name,
                **validated_data 
            )
            for position, photo_file in enumerate(photos_data, start=1):
                Photo.objects.create(
                    announcement=announcement,
                    image=photo_file,
                    position=position
                )

         return announcement

class FavoriteSerializer(serializers.ModelSerializer):
    announcement = AnnouncementListSerializer(read_only=True)
    announcement_id = serializers.PrimaryKeyRelatedField(
        queryset=Announcement.objects.filter(status='active'),
        write_only=True,
        source='announcement'
    )

    class Meta:
        model = Favorite
        fields = ['id', 'announcement', 'announcement_id', 'created_at']
        read_only_fields = ['user_id']


class UniversitySerializer(serializers.ModelSerializer):
    class Meta:
        model = University
        fields = ['id', 'name', 'location', 'domain', 'logo']


class ReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = ['id', 'rating', 'comment', 'created_at', 'updated_at']
        read_only_fields = ['user_id']


class CommentSerializer(serializers.ModelSerializer):
    replies = serializers.SerializerMethodField()
    user_full_name = serializers.SerializerMethodField()

    class Meta:
        model = Comment
        fields = ['id', 'content', 'parent', 'replies', 'user_id', 'user_full_name', 'created_at', 'updated_at']
        read_only_fields = ['user_id']

    def get_user_full_name(self, obj):
        try:
            user = User.objects.get(id=obj.user_id)
            return user.full_name
        except User.DoesNotExist:
            return 'Unknown'

    def get_replies(self, obj):
        replies = obj.replies.all()
        if replies:
            return CommentSerializer(replies, many=True, context=self.context).data
        return []

# add new serializer for the edit listing profile :
class MyAnnouncementSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='title')
    priceValue = serializers.DecimalField(source='price', max_digits=10, decimal_places=2, coerce_to_string=False)
    price = serializers.SerializerMethodField()
    category = serializers.CharField(source='category.name')
    university = serializers.CharField(source='university.name', allow_null=True)
    image = serializers.SerializerMethodField()
    images = serializers.SerializerMethodField()

    class Meta:
        model = Announcement
        fields = [
            'id', 'name', 'title', 'price', 'priceValue',
            'description', 'category', 'university',
            'location', 'image', 'images', 'status', 'created_at','model'
        ]

    def get_price(self, obj):
        return f"{obj.price} DA"

    def get_image(self, obj):
        photos = getattr(obj, 'prefetched_photos', None) or obj.photos.all()
        first = photos[0] if photos else None
        if first and first.image:
            request = self.context.get('request')
            return request.build_absolute_uri(first.image.url) if request else first.image.url
        return None

    def get_images(self, obj):
        request = self.context.get('request')
        photos = getattr(obj, 'prefetched_photos', None) or obj.photos.all()
        return [
            request.build_absolute_uri(p.image.url) if request else p.image.url
            for p in photos if p.image
        ]
    
class ReportSerializer(serializers.ModelSerializer):
    class Meta:
        model = Report
        fields = ['id', 'announcement', 'reason', 'description', 'status', 'created_at']
        read_only_fields = ['status', 'created_at']