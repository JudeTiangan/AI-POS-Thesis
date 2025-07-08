import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderType { pickup, delivery }
enum OrderStatus { pending, preparing, ready, completed, cancelled }
enum PaymentMethod { cash, gcash }
enum PaymentStatus { pending, paid, failed, refunded }

class DeliveryAddress {
  final String street;
  final String city;
  final String province;
  final String postalCode;
  final String contactNumber;
  final String? landmarks;

  DeliveryAddress({
    required this.street,
    required this.city,
    required this.province,
    required this.postalCode,
    required this.contactNumber,
    this.landmarks,
  });

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'city': city,
      'province': province,
      'postalCode': postalCode,
      'contactNumber': contactNumber,
      'landmarks': landmarks,
    };
  }

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      province: json['province'] ?? '',
      postalCode: json['postalCode'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      landmarks: json['landmarks'],
    );
  }
}

class OrderItem {
  final String itemId;
  final String itemName;
  final double price;
  final int quantity;
  final String? itemImageUrl;

  OrderItem({
    required this.itemId,
    required this.itemName,
    required this.price,
    required this.quantity,
    this.itemImageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'price': price,
      'quantity': quantity,
      'itemImageUrl': itemImageUrl,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      itemId: json['itemId'] ?? '',
      itemName: json['itemName'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] ?? 1,
      itemImageUrl: json['itemImageUrl'],
    );
  }
}

class Order {
  final String id;
  final String userId;
  final DateTime createdAt;
  final double totalPrice;
  final List<OrderItem> items;
  final OrderType orderType;
  final OrderStatus orderStatus;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final DeliveryAddress? deliveryAddress;
  final DateTime? estimatedReadyTime;
  final DateTime? completedAt;
  final String? paymentTransactionId;
  final String? paymentSourceId; // PayMongo payment source ID
  final String? adminNotes;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;

  Order({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.totalPrice,
    required this.items,
    required this.orderType,
    required this.orderStatus,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.customerName,
    required this.customerEmail,
    this.deliveryAddress,
    this.estimatedReadyTime,
    this.completedAt,
    this.paymentTransactionId,
    this.paymentSourceId,
    this.adminNotes,
    this.customerPhone,
  });

  // Computed properties
  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);
  
  bool get isOnlineOrder => orderType != OrderType.pickup || paymentMethod == PaymentMethod.gcash;
  
  String get statusDisplayText {
    switch (orderStatus) {
      case OrderStatus.pending:
        return 'Order Received';
      case OrderStatus.preparing:
        return 'Preparing Order';
      case OrderStatus.ready:
        return orderType == OrderType.pickup ? 'Ready for Pickup' : 'Out for Delivery';
      case OrderStatus.completed:
        return orderType == OrderType.pickup ? 'Picked Up' : 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'totalPrice': totalPrice,
      'items': items.map((item) => item.toJson()).toList(),
      'orderType': orderType.name,
      'orderStatus': orderStatus.name,
      'paymentMethod': paymentMethod.name,
      'paymentStatus': paymentStatus.name,
      'deliveryAddress': deliveryAddress?.toJson(),
      'estimatedReadyTime': estimatedReadyTime != null ? Timestamp.fromDate(estimatedReadyTime!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'paymentTransactionId': paymentTransactionId,
      'paymentSourceId': paymentSourceId,
      'adminNotes': adminNotes,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
      orderType: OrderType.values.firstWhere(
        (e) => e.name == json['orderType'],
        orElse: () => OrderType.pickup,
      ),
      orderStatus: OrderStatus.values.firstWhere(
        (e) => e.name == json['orderStatus'],
        orElse: () => OrderStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == json['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (e) => e.name == json['paymentStatus'],
        orElse: () => PaymentStatus.pending,
      ),
      deliveryAddress: json['deliveryAddress'] != null 
          ? DeliveryAddress.fromJson(json['deliveryAddress'] as Map<String, dynamic>)
          : null,
      estimatedReadyTime: _parseDateTime(json['estimatedReadyTime']),
      completedAt: _parseDateTime(json['completedAt']),
      paymentTransactionId: json['paymentTransactionId'],
      paymentSourceId: json['paymentSourceId'],
      adminNotes: json['adminNotes'],
      customerName: json['customerName'] ?? '',
      customerEmail: json['customerEmail'] ?? '',
      customerPhone: json['customerPhone'],
    );
  }

  // Helper method to parse DateTime from both Timestamp and String formats
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    
    if (value is Timestamp) {
      // Firestore Timestamp
      return value.toDate();
    } else if (value is String) {
      // String date from Node.js backend
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('Error parsing date string: $value');
        return null;
      }
    } else if (value is int) {
      // Unix timestamp (milliseconds)
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    
    return null;
  }

  Order copyWith({
    String? id,
    String? userId,
    DateTime? createdAt,
    double? totalPrice,
    List<OrderItem>? items,
    OrderType? orderType,
    OrderStatus? orderStatus,
    PaymentMethod? paymentMethod,
    PaymentStatus? paymentStatus,
    DeliveryAddress? deliveryAddress,
    DateTime? estimatedReadyTime,
    DateTime? completedAt,
    String? paymentTransactionId,
    String? paymentSourceId,
    String? adminNotes,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      totalPrice: totalPrice ?? this.totalPrice,
      items: items ?? this.items,
      orderType: orderType ?? this.orderType,
      orderStatus: orderStatus ?? this.orderStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      estimatedReadyTime: estimatedReadyTime ?? this.estimatedReadyTime,
      completedAt: completedAt ?? this.completedAt,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      paymentSourceId: paymentSourceId ?? this.paymentSourceId,
      adminNotes: adminNotes ?? this.adminNotes,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }
} 