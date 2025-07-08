class CustomerAnalytics {
  final String customerId;
  final Map<String, int> itemPurchaseFrequency; // itemId -> count
  final List<Purchase> purchaseHistory;
  final Map<String, double> categoryPreferences; // categoryId -> preference score
  final DateTime lastPurchase;
  final double averageOrderValue;
  final int totalOrders;
  final List<String> frequentItems; // Most purchased items
  final Map<String, List<String>> associationRules; // item -> associated items

  CustomerAnalytics({
    required this.customerId,
    required this.itemPurchaseFrequency,
    required this.purchaseHistory,
    required this.categoryPreferences,
    required this.lastPurchase,
    required this.averageOrderValue,
    required this.totalOrders,
    required this.frequentItems,
    required this.associationRules,
  });

  factory CustomerAnalytics.fromJson(Map<String, dynamic> json) {
    return CustomerAnalytics(
      customerId: json['customerId'] ?? '',
      itemPurchaseFrequency: Map<String, int>.from(json['itemPurchaseFrequency'] ?? {}),
      purchaseHistory: (json['purchaseHistory'] as List?)
          ?.map((p) => Purchase.fromJson(p))
          .toList() ?? [],
      categoryPreferences: Map<String, double>.from(json['categoryPreferences'] ?? {}),
      lastPurchase: _parseDateTime(json['lastPurchase']),
      averageOrderValue: json['averageOrderValue'] != null 
          ? (json['averageOrderValue'] as num).toDouble()
          : 0.0,
      totalOrders: json['totalOrders'] ?? 0,
      frequentItems: List<String>.from(json['frequentItems'] ?? []),
      associationRules: Map<String, List<String>>.from(
        (json['associationRules'] as Map?)?.map(
          (key, value) => MapEntry(key, List<String>.from(value ?? []))
        ) ?? {}
      ),
    );
  }

  // Helper method to parse different date formats
  static DateTime _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    
    // Handle Firebase Timestamp
    if (dateValue.runtimeType.toString().contains('Timestamp')) {
      return (dateValue as dynamic).toDate();
    }
    
    // Handle ISO string
    if (dateValue is String) {
      return DateTime.parse(dateValue);
    }
    
    // Fallback
    return DateTime.now();
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'itemPurchaseFrequency': itemPurchaseFrequency,
      'purchaseHistory': purchaseHistory.map((p) => p.toJson()).toList(),
      'categoryPreferences': categoryPreferences,
      'lastPurchase': lastPurchase.toIso8601String(),
      'averageOrderValue': averageOrderValue,
      'totalOrders': totalOrders,
      'frequentItems': frequentItems,
      'associationRules': associationRules,
    };
  }
}

class Purchase {
  final String orderId;
  final List<String> itemIds;
  final DateTime timestamp;
  final double totalAmount;
  final List<String> categories;

  Purchase({
    required this.orderId,
    required this.itemIds,
    required this.timestamp,
    required this.totalAmount,
    required this.categories,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      orderId: json['orderId'] ?? '',
      itemIds: List<String>.from(json['itemIds'] ?? []),
      timestamp: CustomerAnalytics._parseDateTime(json['timestamp']),
      totalAmount: json['totalAmount'] != null 
          ? (json['totalAmount'] as num).toDouble()
          : 0.0,
      categories: List<String>.from(json['categories'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'itemIds': itemIds,
      'timestamp': timestamp.toIso8601String(),
      'totalAmount': totalAmount,
      'categories': categories,
    };
  }
}

class AssociationRule {
  final String antecedent; // If customer buys this
  final String consequent; // They also buy this
  final double confidence; // How often this rule is true
  final double support; // How often both items appear together
  final double lift; // How much more likely than random

  AssociationRule({
    required this.antecedent,
    required this.consequent,
    required this.confidence,
    required this.support,
    required this.lift,
  });

  factory AssociationRule.fromJson(Map<String, dynamic> json) {
    return AssociationRule(
      antecedent: json['antecedent'],
      consequent: json['consequent'],
      confidence: (json['confidence'] as num).toDouble(),
      support: (json['support'] as num).toDouble(),
      lift: (json['lift'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'antecedent': antecedent,
      'consequent': consequent,
      'confidence': confidence,
      'support': support,
      'lift': lift,
    };
  }
} 