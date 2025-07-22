import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:frontend/models/item.dart';
import 'package:frontend/services/api_config.dart';
import 'package:frontend/services/firebase_storage_service.dart';

class ItemService {
  final String _baseUrl = ApiConfig.itemsUrl;

  Future<List<Item>> getItems() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        List<Item> items = body.map((dynamic item) => Item.fromJson(item)).toList();
        return items;
      } else {
        throw "Failed to load items";
      }
    } catch (e) {
      print('Error in getItems: $e');
      throw e.toString();
    }
  }

  // Handles creating a new item, with an optional image file
  Future<Item> addItem({required Item item, File? imageFile}) async {
    try {
      print('🔄 Adding item with Firebase Storage: ${imageFile != null ? imageFile.path : 'no image'}');
      
      // First, create the item without image to get an ID
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': item.name,
          'description': item.description,
          'price': item.price,
          'categoryId': item.categoryId,
          'quantity': item.quantity,
          'barcode': item.barcode,
          'imageUrl': null, // Will be updated after image upload
        }),
      );

      print('📋 Item creation response: ${response.statusCode}');

      if (response.statusCode != 201) {
        throw 'Failed to add item. Status: ${response.statusCode}, Body: ${response.body}';
      }

      final createdItem = Item.fromJson(jsonDecode(response.body));
      print('✅ Item created with ID: ${createdItem.id}');

      // If there's an image, upload it to Firebase Storage
      if (imageFile != null && createdItem.id != null) {
        print('🖼️ Uploading image to Firebase Storage...');
        final imageUrl = await FirebaseStorageService.uploadProductImage(
          itemId: createdItem.id!,
          imageFile: imageFile,
        );

        if (imageUrl != null) {
          print('✅ Image uploaded, updating item with URL: $imageUrl');
          // Update the item with the image URL
          await updateItem(
            id: createdItem.id!,
            item: Item(
              id: createdItem.id,
              name: createdItem.name,
              description: createdItem.description,
              price: createdItem.price,
              categoryId: createdItem.categoryId,
              quantity: createdItem.quantity,
              barcode: createdItem.barcode,
              imageUrl: imageUrl,
            ),
          );

          // Return the item with the image URL
          return Item(
            id: createdItem.id,
            name: createdItem.name,
            description: createdItem.description,
            price: createdItem.price,
            categoryId: createdItem.categoryId,
            quantity: createdItem.quantity,
            barcode: createdItem.barcode,
            imageUrl: imageUrl,
          );
        } else {
          print('⚠️ Image upload failed, but item was created');
        }
      }

      return createdItem;
    } catch (e) {
      print('❌ Error in addItem: $e');
      throw e.toString();
    }
  }

  // Handles updating an item, with an optional new image
  Future<void> updateItem({required String id, required Item item, File? imageFile}) async {
    try {
      print('🔄 Updating item $id with Firebase Storage');
      
      String? imageUrl = item.imageUrl; // Keep existing image URL if no new image
      
      // If there's a new image, upload it to Firebase Storage
      if (imageFile != null) {
        print('🖼️ Uploading new image to Firebase Storage...');
        imageUrl = await FirebaseStorageService.uploadProductImage(
          itemId: id,
          imageFile: imageFile,
        );
        
        if (imageUrl != null) {
          print('✅ Image uploaded successfully: $imageUrl');
        } else {
          print('⚠️ Image upload failed, keeping existing image');
          imageUrl = item.imageUrl; // Keep existing image if upload fails
        }
      }

      // Update the item with JSON body
      final response = await http.put(
        Uri.parse('$_baseUrl/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': item.name,
          'description': item.description,
          'price': item.price,
          'categoryId': item.categoryId,
          'quantity': item.quantity,
          'barcode': item.barcode,
          'imageUrl': imageUrl,
        }),
      );

      print('📋 Item update response: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw 'Failed to update item. Status: ${response.statusCode}, Body: ${response.body}';
      }

      print('✅ Item updated successfully');
    } catch (e) {
      print('❌ Error in updateItem: $e');
      throw e.toString();
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      print('🗑️ Deleting item $id and associated image');
      
      // Delete the item from the backend
      final response = await http.delete(Uri.parse('$_baseUrl/$id'));
      if (response.statusCode != 200) {
        throw 'Failed to delete item';
      }
      
      // Also delete the image from Firebase Storage
      await FirebaseStorageService.deleteProductImage(id);
      print('✅ Item and image deleted successfully');
    } catch (e) {
      print('❌ Error in deleteItem: $e');
      throw e.toString();
    }
  }

  Future<Item?> getItemByBarcode(String barcode) async {
    // This requires a new backend endpoint. For now, we simulate by fetching all and filtering.
    // In a real app, you'd have GET /api/items?barcode=...
    try {
      final response = await http.get(Uri.parse('$_baseUrl?barcode=$barcode'));
       if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        if (body.isEmpty) return null;
        return Item.fromJson(body.first);
      } else {
        throw "Failed to load item by barcode";
      }
    } catch (e) {
      print('Error in getItemByBarcode: $e');
      throw e.toString();
    }
  }
} 