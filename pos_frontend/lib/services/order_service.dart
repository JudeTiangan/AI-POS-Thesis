import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/models/item.dart';
import 'package:frontend/models/order.dart'; // We will create this model next
import 'package:frontend/services/ai_recommendation_service.dart';

class OrderService {
  final String _baseUrl = 'http://localhost:3000/api/orders';
  final AIRecommendationService _aiService = AIRecommendationService();

  Future<String> createOrder({
    required String userId,
    required List<Item> items,
    required double totalPrice,
  }) async {
    try {
      // Create lightweight item data without base64 images
      final lightweightItems = items.map((item) => {
        'id': item.id,
        'name': item.name,
        'price': item.price,
        'categoryId': item.categoryId,
        'barcode': item.barcode,
        // Exclude imageUrl to avoid sending massive base64 data
      }).toList();

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'items': lightweightItems,
          'totalPrice': totalPrice,
        }),
      );

      if (response.statusCode == 201) {
        final body = jsonDecode(response.body);
        final orderId = body['orderId'];
        
        // 🧠 Update customer analytics for AI recommendations
        try {
          await _aiService.updateCustomerAnalytics(userId, items, totalPrice);
          print('✅ Customer analytics updated for AI recommendations');
        } catch (e) {
          print('⚠️ Failed to update customer analytics: $e');
          // Don't fail the order if analytics update fails
        }
        
        return orderId; // Return the new order's ID
      } else {
        throw 'Failed to create order. Status: ${response.statusCode}, Body: ${response.body}';
      }
    } catch (e) {
      print('Error in createOrder: $e');
      throw e.toString();
    }
  }

  Future<List<Order>> getUserOrders(String userId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/user/$userId'));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        List<Order> orders = body.map((dynamic item) => Order.fromJson(item)).toList();
        return orders;
      } else {
        throw "Failed to load user's orders";
      }
    } catch (e) {
      print('Error in getUserOrders: $e');
      throw e.toString();
    }
  }
} 