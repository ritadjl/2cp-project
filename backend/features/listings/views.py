from django.shortcuts import render

# Create your views here.
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework import status
from django.shortcuts import get_object_or_404

from .models import Listing
from .serializers import ListingReadSerializer, ListingWriteSerializer
from .permissions import IsSellerOrReadOnly
from features.authentication.models import Student
from django.db import models


class ListingListView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        listings = Listing.objects.filter(
            status=Listing.Status.AVAILABLE
        ).order_by('-created_at')
        serializer = ListingReadSerializer(
            listings, many=True, context={'request': request}
        )
        return Response(serializer.data, status=status.HTTP_200_OK)


class ListingDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, listing_id):
        listing = get_object_or_404(Listing, id=listing_id)
        serializer = ListingReadSerializer(listing, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class ListingCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        student = get_object_or_404(Student, user=request.user)
        serializer = ListingWriteSerializer(
            data=request.data, context={'request': request}
        )
        if serializer.is_valid():
            serializer.save(seller=student)
            return Response(
                {'message': 'Listing created successfully.', 'data': serializer.data},
                status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ListingUpdateView(APIView):
    permission_classes = [IsAuthenticated, IsSellerOrReadOnly]

    def patch(self, request, listing_id):
        listing = get_object_or_404(Listing, id=listing_id)
        self.check_object_permissions(request, listing)
        serializer = ListingWriteSerializer(
            listing, data=request.data, partial=True, context={'request': request}
        )
        if serializer.is_valid():
            serializer.save()
            return Response(
                {'message': 'Listing updated successfully.', 'data': serializer.data},
                status=status.HTTP_200_OK
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ListingDeleteView(APIView):
    permission_classes = [IsAuthenticated, IsSellerOrReadOnly]

    def delete(self, request, listing_id):
        listing = get_object_or_404(Listing, id=listing_id)
        self.check_object_permissions(request, listing)
        listing.delete()
        return Response(
            {'message': 'Listing deleted successfully.'},
            status=status.HTTP_204_NO_CONTENT
        )


class ListingMarkSoldView(APIView):
    permission_classes = [IsAuthenticated, IsSellerOrReadOnly]

    def patch(self, request, listing_id):
        listing = get_object_or_404(Listing, id=listing_id)
        self.check_object_permissions(request, listing)
        listing.status = Listing.Status.SOLD
        listing.save(update_fields=['status'])

        # increment completed_sales on seller's profile
        from features.accounts.models import Profile
        Profile.objects.filter(student=listing.seller).update(
            completed_sales=models.F('completed_sales') + 1
        )

        return Response(
            {'message': 'Listing marked as sold.'},
            status=status.HTTP_200_OK
        )
class MyListingsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        student = get_object_or_404(Student, user=request.user)
        listings = Listing.objects.filter(
            seller=student
        ).order_by('-created_at')
        serializer = ListingReadSerializer(
            listings, many=True, context={'request': request}
        )
        return Response(serializer.data, status=status.HTTP_200_OK)


class SellerListingsView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, student_id):
        student = get_object_or_404(Student, id=student_id)
        listings = Listing.objects.filter(
            seller=student, status=Listing.Status.AVAILABLE
        ).order_by('-created_at')
        serializer = ListingReadSerializer(
            listings, many=True, context={'request': request}
        )
        return Response(serializer.data, status=status.HTTP_200_OK)