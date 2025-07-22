import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/firebase_storage_service.dart';

class ImageMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Migrate all base64 images to Firebase Storage
  /// Call this AFTER you've purchased Firebase Storage
  static Future<Map<String, dynamic>> migrateAllImages() async {
    try {
      print('🔄 Starting image migration from base64 to Firebase Storage...');
      
      // Get all items from Firestore
      final itemsSnapshot = await _firestore.collection('items').get();
      
      int totalItems = itemsSnapshot.docs.length;
      int base64Items = 0;
      int migratedItems = 0;
      int failedItems = 0;
      List<String> failedItemIds = [];
      
      for (final doc in itemsSnapshot.docs) {
        final itemData = doc.data();
        final itemId = doc.id;
        final imageUrl = itemData['imageUrl'] as String?;
        
        print('📋 Processing item: ${itemData['name']} (${itemId})');
        
        // Check if it's a base64 image
        if (imageUrl != null && 
            imageUrl.isNotEmpty && 
            (imageUrl.startsWith('data:image') || imageUrl.startsWith('data:application/octet-stream'))) {
          
          base64Items++;
          print('🖼️ Found base64 image for item: ${itemData['name']}');
          
          try {
            // Convert base64 to bytes
            final parts = imageUrl.split(',');
            if (parts.length == 2) {
              final base64String = parts[1];
              final Uint8List bytes = base64Decode(base64String);
              
              // Upload to Firebase Storage
              final newImageUrl = await FirebaseStorageService.uploadImageFromBytes(
                path: 'products/$itemId.jpg',
                bytes: bytes,
                contentType: 'image/jpeg',
              );
              
              if (newImageUrl != null) {
                // Update item in Firestore with new URL
                await _firestore.collection('items').doc(itemId).update({
                  'imageUrl': newImageUrl,
                  'migratedAt': DateTime.now(),
                  'originalImageType': 'base64',
                });
                
                migratedItems++;
                print('✅ Successfully migrated: ${itemData['name']}');
              } else {
                failedItems++;
                failedItemIds.add(itemId);
                print('❌ Failed to upload image for: ${itemData['name']}');
              }
            } else {
              failedItems++;
              failedItemIds.add(itemId);
              print('❌ Invalid base64 format for: ${itemData['name']}');
            }
          } catch (e) {
            failedItems++;
            failedItemIds.add(itemId);
            print('❌ Error migrating ${itemData['name']}: $e');
          }
        } else {
          print('⏭️ Skipping ${itemData['name']} - not a base64 image');
        }
      }
      
      final result = {
        'totalItems': totalItems,
        'base64Items': base64Items,
        'migratedItems': migratedItems,
        'failedItems': failedItems,
        'failedItemIds': failedItemIds,
        'success': failedItems == 0,
      };
      
      print('🎉 Migration complete!');
      print('📊 Total items: $totalItems');
      print('🖼️ Base64 images found: $base64Items');
      print('✅ Successfully migrated: $migratedItems');
      print('❌ Failed to migrate: $failedItems');
      
      if (failedItems > 0) {
        print('⚠️ Failed item IDs: ${failedItemIds.join(', ')}');
      }
      
      return result;
      
    } catch (e) {
      print('❌ Migration failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'totalItems': 0,
        'base64Items': 0,
        'migratedItems': 0,
        'failedItems': 0,
        'failedItemIds': [],
      };
    }
  }
  
  /// Check how many base64 images need migration
  static Future<Map<String, dynamic>> checkMigrationNeeded() async {
    try {
      print('🔍 Checking for base64 images that need migration...');
      
      final itemsSnapshot = await _firestore.collection('items').get();
      
      int totalItems = itemsSnapshot.docs.length;
      int base64Items = 0;
      List<Map<String, String>> base64ItemsList = [];
      
      for (final doc in itemsSnapshot.docs) {
        final itemData = doc.data();
        final imageUrl = itemData['imageUrl'] as String?;
        
        if (imageUrl != null && 
            imageUrl.isNotEmpty && 
            (imageUrl.startsWith('data:image') || imageUrl.startsWith('data:application/octet-stream'))) {
          
          base64Items++;
          base64ItemsList.add({
            'id': doc.id,
            'name': itemData['name'] as String? ?? 'Unknown',
          });
        }
      }
      
      return {
        'totalItems': totalItems,
        'base64Items': base64Items,
        'base64ItemsList': base64ItemsList,
        'migrationNeeded': base64Items > 0,
      };
      
    } catch (e) {
      print('❌ Error checking migration status: $e');
      return {
        'totalItems': 0,
        'base64Items': 0,
        'base64ItemsList': [],
        'migrationNeeded': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Rollback migration (restore base64 images from backup)
  /// Only use if you have backup data
  static Future<bool> rollbackMigration() async {
    try {
      print('⚠️ Rolling back migration is not implemented.');
      print('💡 Recommendation: Keep a database backup before migrating!');
      return false;
    } catch (e) {
      print('❌ Error during rollback: $e');
      return false;
    }
  }
} 