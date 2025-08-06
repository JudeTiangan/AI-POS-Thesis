import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
  // Get a CORS-compliant download URL for Flutter web
  static Future<String?> getDownloadUrlForWeb(String path) async {
    try {
      if (kIsWeb) {
        // For Flutter web, we need to handle CORS differently
        final storageRef = _storage.ref().child(path);
        
        // Get the download URL
        String downloadUrl = await storageRef.getDownloadURL();
        
        // Add cache-busting parameter to avoid CORS issues
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        downloadUrl = '$downloadUrl&t=$timestamp';
        
        print('🖼️ Generated web-compatible URL: ${downloadUrl.substring(0, 50)}...');
        return downloadUrl;
      } else {
        // For mobile/desktop, use standard approach
        final storageRef = _storage.ref().child(path);
        return await storageRef.getDownloadURL();
      }
    } catch (e) {
      print('❌ Error getting download URL: $e');
      return null;
    }
  }
  
  // Upload product image and return download URL
  static Future<String?> uploadProductImage({
    required String itemId,
    required File imageFile,
  }) async {
    try {
      print('🔄 Uploading image for item: $itemId');
      
      // Create a reference to the storage location
      final storageRef = _storage.ref().child('products/$itemId.jpg');
      
      // Upload the file
      final uploadTask = storageRef.putFile(imageFile);
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL using web-compatible method
      final downloadUrl = await getDownloadUrlForWeb('products/$itemId.jpg');
      
      if (downloadUrl != null) {
        print('✅ Image uploaded successfully: $downloadUrl');
        return downloadUrl;
      } else {
        print('❌ Failed to get download URL');
        return null;
      }
    } catch (e) {
      print('❌ Error uploading image: $e');
      return null;
    }
  }
  
  // Upload image from XFile (for web compatibility)
  static Future<String?> uploadProductImageFromXFile({
    required String itemId,
    required XFile imageFile,
  }) async {
    try {
      print('🔄 Uploading XFile image for item: $itemId');
      
      // Create a reference to the storage location
      final storageRef = _storage.ref().child('products/$itemId.jpg');
      
      // Convert XFile to Uint8List for upload
      final bytes = await imageFile.readAsBytes();
      
      // Upload the bytes
      final uploadTask = storageRef.putData(bytes);
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL using web-compatible method
      final downloadUrl = await getDownloadUrlForWeb('products/$itemId.jpg');
      
      if (downloadUrl != null) {
        print('✅ XFile image uploaded successfully: $downloadUrl');
        return downloadUrl;
      } else {
        print('❌ Failed to get download URL for XFile');
        return null;
      }
    } catch (e) {
      print('❌ Error uploading XFile image: $e');
      return null;
    }
  }

  // Delete product image
  static Future<void> deleteProductImage(String itemId) async {
    try {
      print('🗑️ Deleting image for item: $itemId');
      
      final storageRef = _storage.ref().child('products/$itemId.jpg');
      await storageRef.delete();
      
      print('✅ Image deleted successfully');
    } catch (e) {
      print('❌ Error deleting image: $e');
    }
  }

  // Upload image from bytes (for migration)
  static Future<String?> uploadImageFromBytes({
    required String path,
    required Uint8List bytes,
    String? contentType,
  }) async {
    try {
      print('🔄 Uploading image to path: $path');
      
      final storageRef = _storage.ref().child(path);
      
      // Set metadata if content type is provided
      SettableMetadata? metadata;
      if (contentType != null) {
        metadata = SettableMetadata(contentType: contentType);
      }
      
      // Upload the file
      final uploadTask = metadata != null 
          ? storageRef.putData(bytes, metadata)
          : storageRef.putData(bytes);
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL using web-compatible method
      final downloadUrl = await getDownloadUrlForWeb(path);
      
      if (downloadUrl != null) {
        print('✅ Image uploaded successfully: $downloadUrl');
        return downloadUrl;
      } else {
        print('❌ Failed to get download URL');
        return null;
      }
    } catch (e) {
      print('❌ Error uploading image from bytes: $e');
      return null;
    }
  }
  
  // Get download URL for existing image
  static Future<String?> getImageUrl(String path) async {
    try {
      return await getDownloadUrlForWeb(path);
    } catch (e) {
      print('❌ Error getting image URL: $e');
      return null;
    }
  }
  
  // Check if image exists
  static Future<bool> imageExists(String path) async {
    try {
      final storageRef = _storage.ref().child(path);
      await storageRef.getDownloadURL();
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Generate unique path for product images
  static String generateProductImagePath(String itemId) {
    return 'products/$itemId.jpg';
  }
  
  // Compress and upload image (for better performance)
  static Future<String?> uploadCompressedProductImage({
    required String itemId,
    required File imageFile,
    int quality = 85,
  }) async {
    try {
      print('🔄 Uploading compressed image for item: $itemId');
      
      // For now, just use the regular upload method
      // In a real app, you'd compress the image here
      return await uploadProductImage(
        itemId: itemId,
        imageFile: imageFile,
      );
    } catch (e) {
      print('❌ Error uploading compressed image: $e');
      return null;
    }
  }
} 