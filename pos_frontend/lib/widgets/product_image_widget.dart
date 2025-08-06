import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'dart:convert';

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

  // Helper method to get CORS-friendly URL for web
  String _getWebFriendlyUrl(String url) {
    if (kIsWeb && url.contains('firebasestorage.googleapis.com')) {
      // Use a CORS proxy for Firebase Storage URLs
      return 'https://cors-anywhere.herokuapp.com/$url';
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    // 🔍 DEBUG LOGGING
    print('🖼️ ProductImageWidget: ${imageUrl ?? "NULL"}');
    
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
      print('   ❌ No image URL - showing placeholder');
      return placeholder ?? defaultPlaceholder;
    }

    // Handle base64 images
    if (imageUrl!.startsWith('data:image') || imageUrl!.startsWith('data:application/octet-stream')) {
      print('   🔧 Processing base64 image');
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
                print('   ❌ Base64 error: $error');
                return errorWidget ?? defaultErrorWidget;
              },
            ),
          );
        }
      } catch (e) {
        print('   ❌ Base64 decode error: $e');
        return errorWidget ?? defaultErrorWidget;
      }
    }

    // Handle network images (Firebase Storage URLs)
    if (imageUrl!.startsWith('http')) {
      print('   🌐 Loading network image');
      
      if (kIsWeb) {
        print('   🔧 Using web-optimized approach with CORS proxy');
        
        // For Flutter web, try to load the actual image with CORS proxy
        final webUrl = _getWebFriendlyUrl(imageUrl!);
        print('   🔗 Original URL: $imageUrl');
        print('   🔗 Web URL: $webUrl');
        
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: Image.network(
            webUrl,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                print('   ✅ Image loaded successfully via proxy');
                return child;
              }
              print('   🔄 Loading progress: ${loadingProgress.expectedTotalBytes != null ? (loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! * 100).round() : 0}%');
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
              print('   ❌ Web image error: $error');
              // Show a nice placeholder instead of broken image
              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: borderRadius,
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image,
                        color: Colors.blue[400],
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Product',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      } else {
        // For mobile/desktop, use CachedNetworkImage
        print('   🔧 Using CachedNetworkImage for mobile');
        return ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            width: width,
            height: height,
            fit: fit,
            placeholder: (context, url) {
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
            errorWidget: (context, url, error) {
              print('   ❌ Mobile image error: $error');
              return errorWidget ?? defaultErrorWidget;
            },
          ),
        );
      }
    }

    // Fallback
    print('   ⚠️ Unknown image type - showing placeholder');
    return placeholder ?? defaultPlaceholder;
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