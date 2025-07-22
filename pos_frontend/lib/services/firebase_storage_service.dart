import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  
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
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
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
      print('🔄 Uploading image from XFile for item: $itemId');
      
      // Create a reference to the storage location
      final storageRef = _storage.ref().child('products/$itemId.jpg');
      
      // Get file bytes
      final Uint8List bytes = await imageFile.readAsBytes();
      
      // Upload the file
      final uploadTask = storageRef.putData(bytes);
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image from XFile: $e');
      return null;
    }
  }
  
  // Delete product image
  static Future<bool> deleteProductImage(String itemId) async {
    try {
      print('🗑️ Deleting image for item: $itemId');
      
      final storageRef = _storage.ref().child('products/$itemId.jpg');
      await storageRef.delete();
      
      print('✅ Image deleted successfully');
      return true;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }
  
  // Upload image from bytes (generic method)
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
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading image from bytes: $e');
      return null;
    }
  }
  
  // Get download URL for existing image
  static Future<String?> getImageUrl(String path) async {
    try {
      final storageRef = _storage.ref().child(path);
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
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
      
      // Read file as bytes
      final bytes = await imageFile.readAsBytes();
      
      // For now, upload as-is. In production, you might want to add
      // image compression using packages like flutter_image_compress
      return await uploadImageFromBytes(
        path: generateProductImagePath(itemId),
        bytes: bytes,
        contentType: 'image/jpeg',
      );
    } catch (e) {
      print('❌ Error uploading compressed image: $e');
      return null;
    }
  }
} 