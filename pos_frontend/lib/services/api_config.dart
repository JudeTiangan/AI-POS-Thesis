import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Environment configuration
  // TODO: Replace with your actual Railway URL after deployment
  static const String _productionBaseUrl = 'https://your-app.up.railway.app/api';
  static const String _developmentBaseUrl = 'http://localhost:3000/api';
  
  // Centralized API configuration
  static String get baseUrl {
    // Production mode check
    if (kReleaseMode) {
      // In release mode, use production server
      return _productionBaseUrl;
    }
    
    // Development mode configuration
    if (kIsWeb) {
      // Web builds - use localhost
      return _developmentBaseUrl;
    } else if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      // For real Android devices, you'll need to use your computer's IP address
      return Platform.environment['API_BASE_URL'] ?? 'http://10.0.2.2:3000/api';
    } else if (Platform.isIOS) {
      // iOS simulator can access localhost directly
      return _developmentBaseUrl;
    } else {
      // Desktop platforms (Windows/macOS/Linux)
      return _developmentBaseUrl;
    }
  }
  
  // Get the production-ready base URL for when server is deployed
  static String getProductionUrl() => _productionBaseUrl;
  
  // Get development URL
  static String getDevelopmentUrl() => _developmentBaseUrl;
  
  // Specific endpoint URLs
  static String get ordersUrl => '$baseUrl/orders';
  static String get itemsUrl => '$baseUrl/items';
  static String get categoriesUrl => '$baseUrl/categories';
  static String get authUrl => '$baseUrl/auth';
  static String get recommendationsUrl => '$baseUrl/recommendations';
  static String get analyticsUrl => '$baseUrl/analytics';
  
  // Helper method to get proper redirect URLs for PayMongo
  static String getPaymentRedirectUrl(String path) {
    if (kReleaseMode) {
      return 'https://your-server-domain.com$path';
    } else {
      return 'http://localhost:3000$path';
    }
  }
  
  // Method to check if running in production
  static bool get isProduction => kReleaseMode;
  
  // Method to get current environment
  static String get environment => kReleaseMode ? 'production' : 'development';
} 