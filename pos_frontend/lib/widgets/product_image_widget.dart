import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:typed_data';

class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ProductImageWidget({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Default placeholder
    final defaultPlaceholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
      ),
      child: const Icon(
        Icons.fastfood,
        color: Colors.grey,
        size: 30,
      ),
    );

    // Default error widget
    final defaultErrorWidget = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: borderRadius,
      ),
      child: const Icon(
        Icons.broken_image,
        color: Colors.grey,
        size: 30,
      ),
    );

    // If no image URL, show placeholder
    if (imageUrl == null || imageUrl!.isEmpty) {
      return placeholder ?? defaultPlaceholder;
    }

    // Handle base64 images (for backwards compatibility)
    if (imageUrl!.startsWith('data:image') || imageUrl!.startsWith('data:application/octet-stream')) {
      try {
        final parts = imageUrl!.split(',');
        if (parts.length == 2) {
          final base64String = parts[1];
          final Uint8List bytes = base64Decode(base64String);
          return ClipRRect(
            borderRadius: borderRadius ?? BorderRadius.zero,
            child: Image.memory(
              bytes,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                print('❌ Error loading base64 image: $error');
                return errorWidget ?? defaultErrorWidget;
              },
            ),
          );
        }
      } catch (e) {
        print('❌ Error decoding base64 image: $e');
        return errorWidget ?? defaultErrorWidget;
      }
    }

    // Check if it's a Firebase Storage URL or other network image
    if (imageUrl!.startsWith('http')) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: width,
          height: height,
          fit: fit,
          placeholder: (context, url) => Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: borderRadius,
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) {
            print('❌ Error loading network image: $url - $error');
            return errorWidget ?? defaultErrorWidget;
          },
        ),
      );
    }

    // Fallback for any other type of image URL
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        imageUrl!,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: borderRadius,
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Error loading image: $imageUrl - $error');
          return errorWidget ?? defaultErrorWidget;
        },
      ),
    );
  }
}

// Specific widget for product thumbnails
class ProductThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final BorderRadius? borderRadius;

  const ProductThumbnail({
    super.key,
    this.imageUrl,
    this.size = 50,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ProductImageWidget(
      imageUrl: imageUrl,
      width: size,
      height: size,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
    );
  }
}

// Specific widget for product cards
class ProductCardImage extends StatelessWidget {
  final String? imageUrl;
  final double height;
  final BorderRadius? borderRadius;

  const ProductCardImage({
    super.key,
    this.imageUrl,
    this.height = 100,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ProductImageWidget(
      imageUrl: imageUrl,
      width: double.infinity,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
    );
  }
}

// Specific widget for full product image display
class ProductImageDisplay extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;

  const ProductImageDisplay({
    super.key,
    this.imageUrl,
    this.width,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return ProductImageWidget(
      imageUrl: imageUrl,
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(12),
      placeholder: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No image',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
} 