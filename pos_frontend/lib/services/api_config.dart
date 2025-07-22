import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  // Environment configuration  
  static const String _productionBaseUrl = 'https://ai-pos-thesis-2.onrender.com';
  static const String _developmentBaseUrl = 'http://localhost:3000';
  
  // Smart environment detection for thesis demo
  static String get baseUrl {
    // APK/Release builds automatically use hosted backend
    if (kReleaseMode) {
      return _productionBaseUrl;
    }
    
    // Development mode - can switch between local and hosted
    // Set USE_HOSTED_BACKEND=true to test with hosted backend locally
    const bool useHostedInDev = bool.fromEnvironment('USE_HOSTED_BACKEND', defaultValue: false);
    
    if (useHostedInDev) {
      return _productionBaseUrl;  // Use hosted backend for local testing
    }
    
    // Platform-specific local development
    if (kIsWeb) {
      return _developmentBaseUrl;
    } else if (Platform.isAndroid) {
      // Android emulator/device accessing local backend
      return 'http://10.0.2.2:3000';  // Removed /api - it gets added in endpoint URLs
    } else {
      // Desktop/iOS development
      return _developmentBaseUrl;
    }
  }
  
  // Get the production-ready base URL for when server is deployed
  static String getProductionUrl() => _productionBaseUrl;
  
  // Get development URL
  static String getDevelopmentUrl() => _developmentBaseUrl;
  
  // Specific endpoint URLs
  static String get ordersUrl => '$baseUrl/api/orders';
  static String get itemsUrl => '$baseUrl/api/items';
  static String get categoriesUrl => '$baseUrl/api/categories';
  static String get authUrl => '$baseUrl/api/auth';
  static String get recommendationsUrl => '$baseUrl/api/recommendations';
  static String get analyticsUrl => '$baseUrl/api/analytics';
  
  // Helper method to get proper redirect URLs for PayMongo
  static String getPaymentRedirectUrl(String path) {
    if (kReleaseMode) {
      return 'https://ai-pos-thesis-2.onrender.com$path';
    } else {
      return 'http://localhost:3000$path';
    }
  }
  
  // Method to check if running in production
  static bool get isProduction => kReleaseMode;
  
  // Method to get current environment
  static String get environment => kReleaseMode ? 'production' : 'development';
} 