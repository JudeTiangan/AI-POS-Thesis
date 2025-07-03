import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:frontend/models/item.dart';

class ItemService {
  // TODO: Replace with your actual backend URL.
  final String _baseUrl = 'http://localhost:3000/api/items';

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
      print('Adding item with image: ${imageFile != null ? imageFile.path : 'no image'}');
      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      
      // Add text fields
      request.fields['name'] = item.name;
      request.fields['description'] = item.description;
      request.fields['price'] = item.price.toString();
      request.fields['categoryId'] = item.categoryId;
      request.fields['quantity'] = item.quantity.toString();
      if (item.barcode != null) {
        request.fields['barcode'] = item.barcode!;
      }

      // Add image file if it exists
      if (imageFile != null) {
        print('Adding image file to request: ${imageFile.path}');
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }

      print('Sending request to: $_baseUrl');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        return Item.fromJson(jsonDecode(response.body));
      } else {
        throw 'Failed to add item. Status: ${response.statusCode}, Body: ${response.body}';
      }
    } catch (e) {
      print('Error in addItem: $e');
      throw e.toString();
    }
  }

  // Handles updating an item, with an optional new image
  Future<void> updateItem({required String id, required Item item, File? imageFile}) async {
    try {
       var request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/$id'));

      // Add text fields
      request.fields['name'] = item.name;
      request.fields['description'] = item.description;
      request.fields['price'] = item.price.toString();
      request.fields['categoryId'] = item.categoryId;
      request.fields['quantity'] = item.quantity.toString();
       if (item.barcode != null) {
        request.fields['barcode'] = item.barcode!;
      }

      // Add image file if it exists
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }

      var streamedResponse = await request.send();
       var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw 'Failed to update item. Status: ${response.statusCode}, Body: ${response.body}';
      }
    } catch (e) {
      print('Error in updateItem: $e');
      throw e.toString();
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/$id'));
      if (response.statusCode != 200) {
        throw 'Failed to delete item';
      }
    } catch (e) {
      print('Error in deleteItem: $e');
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