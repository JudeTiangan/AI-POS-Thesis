import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/models/order.dart';
import 'package:frontend/services/api_config.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderService {
  static String get baseUrl => ApiConfig.ordersUrl;

  // Create a new order
  static Future<Map<String, dynamic>> createOrder({
    required String userId,
    required List<OrderItem> items,
    required double totalPrice,
    required OrderType orderType,
    required PaymentMethod paymentMethod,
    required String customerName,
    required String customerEmail,
    String? customerPhone,
    DeliveryAddress? deliveryAddress,
  }) async {
    try {
      print('🔄 Creating order with API: ${ApiConfig.baseUrl}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.ordersUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': userId,
          'items': items.map((item) => item.toJson()).toList(),
          'totalPrice': totalPrice,
          'orderType': orderType.name,
          'paymentMethod': paymentMethod.name,
          'customerName': customerName,
          'customerEmail': customerEmail,
          'customerPhone': customerPhone,
          'deliveryAddress': deliveryAddress?.toJson(),
        }),
      );

      print('📋 Order creation response: ${response.statusCode}');
      print('📋 Response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('📋 Response data type: ${responseData.runtimeType}');
        print('📋 Order data type: ${responseData['order'].runtimeType}');
        print('📋 Order data: ${responseData['order']}');
        
        try {
          // Ensure the order data is a Map before parsing
          final orderData = responseData['order'];
          Order order;
          
          if (orderData is Map<String, dynamic>) {
            order = Order.fromJson(orderData);
          } else {
            print('❌ Order data is not a Map, attempting to convert...');
            // If it's already an Order object, create a new one with an ID
            final Map<String, dynamic> orderMap = {
              'id': responseData['order']['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'userId': responseData['order']['userId'] ?? '',
              'createdAt': DateTime.now().toIso8601String(),
              'totalPrice': responseData['order']['totalPrice'] ?? 0.0,
              'items': responseData['order']['items'] ?? [],
              'orderType': responseData['order']['orderType'] ?? 'pickup',
              'orderStatus': responseData['order']['orderStatus'] ?? 'pending',
              'paymentMethod': responseData['order']['paymentMethod'] ?? 'cash',
              'paymentStatus': responseData['order']['paymentStatus'] ?? 'pending',
              'customerName': responseData['order']['customerName'] ?? '',
              'customerEmail': responseData['order']['customerEmail'] ?? '',
            };
            order = Order.fromJson(orderMap);
          }
          
          return {
            'success': true,
            'order': order,
            'paymentUrl': responseData['paymentUrl'], // For GCash payments
          };
        } catch (e) {
          print('❌ Error parsing order response: $e');
          return {
            'success': false,
            'message': 'Failed to parse order response: $e',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Failed to create order: ${response.body}',
        };
      }
    } catch (e) {
      print('❌ Error creating order: $e');
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Get user orders
  static Future<List<Order>> getUserOrders() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ User not authenticated');
        throw Exception('User not authenticated');
      }

      print('👤 Current user ID: ${user.uid}');
      print('🔗 API URL: $baseUrl/user/${user.uid}');

      final response = await http.get(
        Uri.parse('$baseUrl/user/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> ordersData = jsonDecode(response.body);
        print('✅ Successfully parsed ${ordersData.length} orders');
        return ordersData.map((orderJson) => Order.fromJson(orderJson)).toList();
      } else {
        print('❌ API error response: ${response.body}');
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch orders');
      }
    } catch (e) {
      print('❌ Error fetching user orders: $e');
      rethrow;
    }
  }

  // Get all orders for admin
  static Future<List<Order>> getAdminOrders({
    String? status,
    String? orderType,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (status != null) queryParams['status'] = status;
      if (orderType != null) queryParams['orderType'] = orderType;

      final uri = Uri.parse('$baseUrl/admin').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> ordersData = jsonDecode(response.body);
        return ordersData.map((orderJson) => Order.fromJson(orderJson)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to fetch admin orders');
      }
    } catch (e) {
      print('Error fetching admin orders: $e');
      rethrow;
    }
  }

  // Update order status (admin only)
  static Future<bool> updateOrderStatus({
    required String orderId,
    required OrderStatus orderStatus,
    String? adminNotes,
    DateTime? estimatedReadyTime,
  }) async {
    try {
      final requestBody = {
        'orderStatus': orderStatus.name,
        if (adminNotes != null) 'adminNotes': adminNotes,
        if (estimatedReadyTime != null) 'estimatedReadyTime': estimatedReadyTime.toIso8601String(),
      };

      final response = await http.put(
        Uri.parse('$baseUrl/$orderId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }

  // Update payment status
  static Future<bool> updatePaymentStatus({
    required String orderId,
    required PaymentStatus paymentStatus,
    String? paymentTransactionId,
  }) async {
    try {
      final requestBody = {
        'paymentStatus': paymentStatus.name,
        if (paymentTransactionId != null) 'paymentTransactionId': paymentTransactionId,
      };

      final response = await http.put(
        Uri.parse('$baseUrl/$orderId/payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating payment status: $e');
      return false;
    }
  }

  // Get specific order by ID
  static Future<Order?> getOrderById(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$orderId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final orderData = jsonDecode(response.body);
        return Order.fromJson(orderData);
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching order: $e');
      return null;
    }
  }

  // Delete order (admin only, for completed orders)
  static Future<bool> deleteOrder(String orderId) async {
    try {
      print('🗑️ Attempting to delete order: $orderId');
      print('🔗 DELETE URL: $baseUrl/$orderId');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/$orderId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📋 Delete response status: ${response.statusCode}');
      print('📋 Delete response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Order $orderId deleted successfully');
        return true;
      } else {
        // Parse error message from response
        String errorMessage = 'Unknown error';
        try {
          final error = jsonDecode(response.body);
          errorMessage = error['message'] ?? 'Delete request failed';
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        }
        
        print('❌ Failed to delete order: $errorMessage');
        return false;
      }
    } catch (e) {
      print('❌ Error deleting order: $e');
      return false;
    }
  }

  // Helper method to calculate estimated delivery time
  static DateTime calculateEstimatedDeliveryTime({
    required OrderType orderType,
    int preparationMinutes = 15,
    int deliveryMinutes = 30,
  }) {
    final now = DateTime.now();
    if (orderType == OrderType.pickup) {
      return now.add(Duration(minutes: preparationMinutes));
    } else {
      return now.add(Duration(minutes: preparationMinutes + deliveryMinutes));
    }
  }

  // Helper method to get orders by status
  static Future<List<Order>> getOrdersByStatus(OrderStatus status) async {
    return await getAdminOrders(status: status.name);
  }

  // Helper method to get pending payments
  static Future<List<Order>> getPendingPayments() async {
    try {
      final orders = await getAdminOrders();
      return orders.where((order) => 
        order.paymentStatus == PaymentStatus.pending && 
        order.paymentMethod == PaymentMethod.gcash
      ).toList();
    } catch (e) {
      print('Error fetching pending payments: $e');
      return [];
    }
  }
} 