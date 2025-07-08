import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/models/item.dart';
import 'package:frontend/models/customer_analytics.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/api_config.dart';

class AIRecommendationService {
  final String _baseUrl = ApiConfig.baseUrl;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  /// Main method to get personalized recommendations
  Future<List<Item>> getPersonalizedRecommendations({
    required List<Item> currentCart,
    required List<Item> allItems,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        // For anonymous users, use basic association rules
        return await _getBasicAssociationRecommendations(currentCart, allItems);
      }

      // Get customer analytics
      final customerAnalytics = await _getCustomerAnalytics(user.uid);
      
      // Apply multiple recommendation algorithms
      final recommendations = await _generateAdvancedRecommendations(
        customerId: user.uid,
        currentCart: currentCart,
        allItems: allItems,
        customerAnalytics: customerAnalytics,
      );

      return recommendations;
    } catch (e) {
      print('Error in personalized recommendations: $e');
      // Fallback to basic recommendations
      return await _getBasicAssociationRecommendations(currentCart, allItems);
    }
  }

  /// Advanced recommendation algorithm combining multiple techniques
  Future<List<Item>> _generateAdvancedRecommendations({
    required String customerId,
    required List<Item> currentCart,
    required List<Item> allItems,
    required CustomerAnalytics? customerAnalytics,
  }) async {
    Map<String, double> itemScores = {};

    // 1. Association Rule Mining (Market Basket Analysis)
    final associationScores = await _calculateAssociationScores(currentCart, allItems);
    
    // 2. Customer Behavior Analysis
    final behaviorScores = _calculateCustomerBehaviorScores(customerAnalytics, allItems);
    
    // 3. Collaborative Filtering
    final collaborativeScores = await _calculateCollaborativeFilteringScores(customerId, allItems);
    
    // 4. Trend Analysis
    final trendScores = await _calculateTrendScores(allItems);
    
    // 5. Category Preference Analysis
    final categoryScores = _calculateCategoryPreferenceScores(customerAnalytics, allItems);

    // Combine all scores with weights
    for (final item in allItems) {
      if (_isItemInCart(item, currentCart)) continue; // Skip items already in cart
      
      double totalScore = 0.0;
      totalScore += (associationScores[item.id] ?? 0.0) * 0.35; // 35% weight for associations
      totalScore += (behaviorScores[item.id] ?? 0.0) * 0.25;    // 25% weight for behavior
      totalScore += (collaborativeScores[item.id] ?? 0.0) * 0.20; // 20% weight for collaborative
      totalScore += (trendScores[item.id] ?? 0.0) * 0.10;       // 10% weight for trends
      totalScore += (categoryScores[item.id] ?? 0.0) * 0.10;    // 10% weight for categories
      
      itemScores[item.id!] = totalScore;
    }

    // Sort items by score and return top recommendations
    final sortedItems = itemScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final recommendedItems = <Item>[];
    for (final entry in sortedItems.take(5)) {
      final item = allItems.firstWhere((item) => item.id == entry.key);
      recommendedItems.add(item);
    }

    return recommendedItems;
  }

  /// Market Basket Analysis - Association Rule Mining
  Future<Map<String, double>> _calculateAssociationScores(
    List<Item> currentCart, 
    List<Item> allItems
  ) async {
    Map<String, double> scores = {};
    
    if (currentCart.isEmpty) return scores;

    try {
      // Get all order data for association analysis
      final ordersSnapshot = await _firestore.collection('orders').get();
      final orderItemsSnapshot = await _firestore.collection('orderItems').get();

      // Build transaction database
      Map<String, List<String>> transactions = {};
      
      for (final orderDoc in ordersSnapshot.docs) {
        final orderId = orderDoc.id;
        transactions[orderId] = [];
      }

      for (final orderItemDoc in orderItemsSnapshot.docs) {
        final data = orderItemDoc.data();
        final orderId = data['orderId'];
        final itemId = data['itemId'];
        
        if (transactions.containsKey(orderId)) {
          transactions[orderId]!.add(itemId);
        }
      }

      // Calculate association rules
      final cartItemIds = currentCart.map((item) => item.id!).toList();
      
      for (final item in allItems) {
        if (_isItemInCart(item, currentCart)) continue;
        
        double confidence = _calculateConfidence(cartItemIds, item.id!, transactions);
        double support = _calculateSupport(cartItemIds + [item.id!], transactions);
        double lift = _calculateLift(cartItemIds, item.id!, transactions);
        
        // Weighted association score
        scores[item.id!] = (confidence * 0.5) + (support * 0.3) + ((lift - 1.0) * 0.2);
      }
    } catch (e) {
      print('Error in association analysis: $e');
    }

    return scores;
  }

  /// Customer Behavior Analysis
  Map<String, double> _calculateCustomerBehaviorScores(
    CustomerAnalytics? analytics, 
    List<Item> allItems
  ) {
    Map<String, double> scores = {};
    
    if (analytics == null) return scores;

    for (final item in allItems) {
      double score = 0.0;
      
      // Frequency score - how often customer bought this item
      final frequency = analytics.itemPurchaseFrequency[item.id] ?? 0;
      score += frequency / max(analytics.totalOrders, 1) * 0.4;
      
      // Recency score - when did they last buy similar items
      final daysSinceLastPurchase = DateTime.now().difference(analytics.lastPurchase).inDays;
      score += max(0, (30 - daysSinceLastPurchase) / 30) * 0.3;
      
      // Category preference score
      final categoryPreference = analytics.categoryPreferences[item.categoryId] ?? 0.0;
      score += categoryPreference * 0.3;
      
      scores[item.id!] = score;
    }

    return scores;
  }

  /// Collaborative Filtering - "Customers like you also bought"
  Future<Map<String, double>> _calculateCollaborativeFilteringScores(
    String customerId, 
    List<Item> allItems
  ) async {
    Map<String, double> scores = {};
    
    try {
      // Find similar customers based on purchase history
      final customerAnalytics = await _getAllCustomerAnalytics();
      final currentCustomer = customerAnalytics[customerId];
      
      if (currentCustomer == null) return scores;

      // Calculate customer similarity
      Map<String, double> customerSimilarity = {};
      
      for (final entry in customerAnalytics.entries) {
        if (entry.key == customerId) continue;
        
        final similarity = _calculateCustomerSimilarity(currentCustomer, entry.value);
        if (similarity > 0.1) { // Only consider reasonably similar customers
          customerSimilarity[entry.key] = similarity;
        }
      }

      // Weight recommendations by similar customers' preferences
      for (final item in allItems) {
        double weightedScore = 0.0;
        double totalWeight = 0.0;
        
        for (final entry in customerSimilarity.entries) {
          final similarCustomer = customerAnalytics[entry.key]!;
          final similarity = entry.value;
          final itemFrequency = similarCustomer.itemPurchaseFrequency[item.id] ?? 0;
          
          weightedScore += similarity * itemFrequency;
          totalWeight += similarity;
        }
        
        scores[item.id!] = totalWeight > 0 ? weightedScore / totalWeight : 0.0;
      }
    } catch (e) {
      print('Error in collaborative filtering: $e');
    }

    return scores;
  }

  /// Trend Analysis - Popular items trending up
  Future<Map<String, double>> _calculateTrendScores(List<Item> allItems) async {
    Map<String, double> scores = {};
    
    try {
      final now = DateTime.now();
      final oneWeekAgo = now.subtract(const Duration(days: 7));
      final twoWeeksAgo = now.subtract(const Duration(days: 14));

      // Get recent order data
      final recentOrdersSnapshot = await _firestore
          .collection('orders')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(twoWeeksAgo))
          .get();

      Map<String, int> thisWeekCounts = {};
      Map<String, int> lastWeekCounts = {};

      for (final orderDoc in recentOrdersSnapshot.docs) {
        final data = orderDoc.data();
        final createdAt = (data['createdAt'] as Timestamp).toDate();
        final orderId = orderDoc.id;

        // Get order items for this order
        final orderItemsSnapshot = await _firestore
            .collection('orderItems')
            .where('orderId', isEqualTo: orderId)
            .get();

        for (final orderItemDoc in orderItemsSnapshot.docs) {
          final itemId = orderItemDoc.data()['itemId'];
          
          if (createdAt.isAfter(oneWeekAgo)) {
            thisWeekCounts[itemId] = (thisWeekCounts[itemId] ?? 0) + 1;
          } else {
            lastWeekCounts[itemId] = (lastWeekCounts[itemId] ?? 0) + 1;
          }
        }
      }

      // Calculate trend scores
      for (final item in allItems) {
        final thisWeek = thisWeekCounts[item.id] ?? 0;
        final lastWeek = lastWeekCounts[item.id] ?? 0;
        
        if (lastWeek > 0) {
          final trendRatio = thisWeek / lastWeek;
          scores[item.id!] = max(0, trendRatio - 1.0); // Positive trend score
        } else if (thisWeek > 0) {
          scores[item.id!] = 1.0; // New trending item
        } else {
          scores[item.id!] = 0.0;
        }
      }
    } catch (e) {
      print('Error in trend analysis: $e');
    }

    return scores;
  }

  /// Category Preference Analysis
  Map<String, double> _calculateCategoryPreferenceScores(
    CustomerAnalytics? analytics, 
    List<Item> allItems
  ) {
    Map<String, double> scores = {};
    
    if (analytics == null) return scores;

    for (final item in allItems) {
      scores[item.id!] = analytics.categoryPreferences[item.categoryId] ?? 0.0;
    }

    return scores;
  }

  // Helper Methods

  double _calculateConfidence(List<String> antecedent, String consequent, Map<String, List<String>> transactions) {
    int antecedentCount = 0;
    int bothCount = 0;

    for (final transaction in transactions.values) {
      final hasAntecedent = antecedent.every((item) => transaction.contains(item));
      if (hasAntecedent) {
        antecedentCount++;
        if (transaction.contains(consequent)) {
          bothCount++;
        }
      }
    }

    return antecedentCount > 0 ? bothCount / antecedentCount : 0.0;
  }

  double _calculateSupport(List<String> itemset, Map<String, List<String>> transactions) {
    int count = 0;
    for (final transaction in transactions.values) {
      if (itemset.every((item) => transaction.contains(item))) {
        count++;
      }
    }
    return transactions.isNotEmpty ? count / transactions.length : 0.0;
  }

  double _calculateLift(List<String> antecedent, String consequent, Map<String, List<String>> transactions) {
    final confidence = _calculateConfidence(antecedent, consequent, transactions);
    final consequentSupport = _calculateSupport([consequent], transactions);
    return consequentSupport > 0 ? confidence / consequentSupport : 0.0;
  }

  double _calculateCustomerSimilarity(CustomerAnalytics customer1, CustomerAnalytics customer2) {
    // Cosine similarity based on item purchase frequencies
    final items1 = customer1.itemPurchaseFrequency;
    final items2 = customer2.itemPurchaseFrequency;
    
    final commonItems = items1.keys.toSet().intersection(items2.keys.toSet());
    if (commonItems.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (final item in commonItems) {
      final freq1 = items1[item]!.toDouble();
      final freq2 = items2[item]!.toDouble();
      
      dotProduct += freq1 * freq2;
      norm1 += freq1 * freq1;
      norm2 += freq2 * freq2;
    }

    final magnitude = sqrt(norm1) * sqrt(norm2);
    return magnitude > 0 ? dotProduct / magnitude : 0.0;
  }

  bool _isItemInCart(Item item, List<Item> cart) {
    return cart.any((cartItem) => cartItem.id == item.id);
  }

  // Data Management Methods

  Future<CustomerAnalytics?> _getCustomerAnalytics(String customerId) async {
    try {
      final doc = await _firestore.collection('customerAnalytics').doc(customerId).get();
      if (doc.exists) {
        return CustomerAnalytics.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      print('Error getting customer analytics: $e');
      return null;
    }
  }

  Future<Map<String, CustomerAnalytics>> _getAllCustomerAnalytics() async {
    try {
      final snapshot = await _firestore.collection('customerAnalytics').get();
      Map<String, CustomerAnalytics> analytics = {};
      
      for (final doc in snapshot.docs) {
        analytics[doc.id] = CustomerAnalytics.fromJson(doc.data());
      }
      
      return analytics;
    } catch (e) {
      print('Error getting all customer analytics: $e');
      return {};
    }
  }

  /// Update customer analytics after a purchase
  Future<void> updateCustomerAnalytics(String customerId, List<Item> purchasedItems, double totalAmount) async {
    try {
      final docRef = _firestore.collection('customerAnalytics').doc(customerId);
      final doc = await docRef.get();
      
      CustomerAnalytics analytics;
      if (doc.exists) {
        analytics = CustomerAnalytics.fromJson(doc.data()!);
      } else {
        // Create new analytics for first-time customer
        analytics = CustomerAnalytics(
          customerId: customerId,
          itemPurchaseFrequency: {},
          purchaseHistory: [],
          categoryPreferences: {},
          lastPurchase: DateTime.now(),
          averageOrderValue: 0.0,
          totalOrders: 0,
          frequentItems: [],
          associationRules: {},
        );
      }

      // Update analytics with new purchase
      final updatedAnalytics = _updateAnalyticsWithPurchase(analytics, purchasedItems, totalAmount);
      
      await docRef.set(updatedAnalytics.toJson());
    } catch (e) {
      print('Error updating customer analytics: $e');
    }
  }

  CustomerAnalytics _updateAnalyticsWithPurchase(CustomerAnalytics analytics, List<Item> items, double totalAmount) {
    final updatedFrequency = Map<String, int>.from(analytics.itemPurchaseFrequency);
    final updatedCategoryPreferences = Map<String, double>.from(analytics.categoryPreferences);
    
    // Update item frequencies
    for (final item in items) {
      updatedFrequency[item.id!] = (updatedFrequency[item.id!] ?? 0) + 1;
      
      // Update category preferences
      final currentPreference = updatedCategoryPreferences[item.categoryId] ?? 0.0;
      updatedCategoryPreferences[item.categoryId] = currentPreference + 0.1;
    }

    // Calculate new average order value
    final newTotalOrders = analytics.totalOrders + 1;
    final newAverageOrderValue = 
        ((analytics.averageOrderValue * analytics.totalOrders) + totalAmount) / newTotalOrders;

    // Update frequent items (top 5 most purchased)
    final sortedItems = updatedFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final frequentItems = sortedItems.take(5).map((e) => e.key).toList();

    return CustomerAnalytics(
      customerId: analytics.customerId,
      itemPurchaseFrequency: updatedFrequency,
      purchaseHistory: analytics.purchaseHistory + [
        Purchase(
          orderId: DateTime.now().millisecondsSinceEpoch.toString(),
          itemIds: items.map((item) => item.id!).toList(),
          timestamp: DateTime.now(),
          totalAmount: totalAmount,
          categories: items.map((item) => item.categoryId).toSet().toList(),
        )
      ],
      categoryPreferences: updatedCategoryPreferences,
      lastPurchase: DateTime.now(),
      averageOrderValue: newAverageOrderValue,
      totalOrders: newTotalOrders,
      frequentItems: frequentItems,
      associationRules: analytics.associationRules,
    );
  }

  /// Fallback basic association recommendations
  Future<List<Item>> _getBasicAssociationRecommendations(List<Item> currentCart, List<Item> allItems) async {
    // Simple rule-based recommendations for coffee shop
    final Map<String, List<String>> basicRules = {
      'coffee': ['sugar', 'milk', 'creamer', 'cookie'],
      'tea': ['honey', 'lemon', 'sugar'],
      'nescafe': ['sugar', 'milk', 'creamer'],
      'espresso': ['sugar', 'cookie'],
      'latte': ['cookie', 'muffin'],
    };

    final recommendations = <Item>[];
    
    for (final cartItem in currentCart) {
      final itemName = cartItem.name.toLowerCase();
      
      for (final rule in basicRules.entries) {
        if (itemName.contains(rule.key)) {
          for (final associatedItem in rule.value) {
            final matchingItems = allItems.where((item) => 
              item.name.toLowerCase().contains(associatedItem) && 
              !_isItemInCart(item, currentCart)
            );
            
            if (matchingItems.isNotEmpty && !recommendations.contains(matchingItems.first)) {
              recommendations.add(matchingItems.first);
            }
          }
        }
      }
    }

    return recommendations.take(5).toList();
  }
} 