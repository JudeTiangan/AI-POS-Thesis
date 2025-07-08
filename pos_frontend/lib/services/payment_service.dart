import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/services/api_config.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentService {
  
  /// Minimum amount for GCash payments (PayMongo requirement)
  static const double minimumGCashAmount = 20.0;
  
  /// Validate minimum amount for GCash payments
  static Map<String, dynamic> validatePaymentAmount(double amount, String paymentMethod) {
    if (paymentMethod.toLowerCase() == 'gcash' && amount < minimumGCashAmount) {
      return {
        'isValid': false,
        'error': 'Minimum amount for GCash payments is ₱${minimumGCashAmount.toStringAsFixed(2)}',
        'currentAmount': amount,
        'minimumAmount': minimumGCashAmount,
      };
    }
    
    return {
      'isValid': true,
      'error': '', // Provide empty string instead of null
    };
  }
  
  /// Open payment URL in external browser or in-app browser
  static Future<bool> openPaymentUrl(String paymentUrl) async {
    try {
      final Uri uri = Uri.parse(paymentUrl);
      
      // Use external browser for better payment security
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Opens in external browser
        );
      } else {
        throw Exception('Could not launch payment URL');
      }
    } catch (e) {
      print('Error opening payment URL: $e');
      return false;
    }
  }

  /// Check payment status by polling the backend
  static Future<Map<String, dynamic>> checkPaymentStatus(String paymentSourceId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/orders/payment-status/$paymentSourceId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? true,
          'status': data['status'],
          'paymentIntent': data['paymentIntent'],
          'error': data['error'],
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'error': errorData['message'] ?? 'Failed to check payment status: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Poll payment status until completion or timeout
  static Future<Map<String, dynamic>> pollPaymentStatus({
    required String paymentSourceId,
    int maxAttempts = 60, // 5 minutes with 5-second intervals
    Duration interval = const Duration(seconds: 5),
  }) async {
    int attempts = 0;
    
    while (attempts < maxAttempts) {
      try {
        print('🔍 Checking payment status (attempt ${attempts + 1}/$maxAttempts)');
        final result = await checkPaymentStatus(paymentSourceId);
        
        print('💳 Payment status result: $result');
        
        if (!result['success']) {
          print('❌ Payment status check failed: ${result['error']}');
          return {
            'success': false,
            'error': result['error'] ?? 'Payment status check failed',
          };
        }

        final status = result['status'];
        print('📊 Current payment status: $status');
        
        // Check if payment is completed
        if (status == 'succeeded' || status == 'chargeable' || status == 'consumed') {
          return {
            'success': true,
            'status': 'paid',
            'message': 'Payment successful!',
          };
        } else if (status == 'failed' || status == 'cancelled' || status == 'expired') {
          return {
            'success': false,
            'status': status,
            'message': 'Payment $status',
          };
        }

        // Continue polling if still processing
        await Future.delayed(interval);
        attempts++;
        
      } catch (e) {
        print('❌ Error during payment status check: $e');
        attempts++;
        if (attempts >= maxAttempts) {
          return {
            'success': false,
            'error': 'Payment status check timeout: $e',
          };
        }
        await Future.delayed(interval);
      }
    }

    return {
      'success': false,
      'error': 'Payment status check timeout',
    };
  }

  /// Get human-readable payment status
  static String getPaymentStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Payment is being processed...';
      case 'chargeable':
        return 'Payment successful!';
      case 'succeeded':
        return 'Payment successful!';
      case 'consumed':
        return 'Payment completed!';
      case 'failed':
        return 'Payment failed. Please try again.';
      case 'cancelled':
        return 'Payment was cancelled.';
      case 'expired':
        return 'Payment session expired. Please try again.';
      case 'awaiting_payment_method':
        return 'Waiting for payment method...';
      case 'awaiting_next_action':
        return 'Please complete payment in your browser...';
      case 'processing':
        return 'Processing payment...';
      default:
        return 'Payment status: $status';
    }
  }
} 