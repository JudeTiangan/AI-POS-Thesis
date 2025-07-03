import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String id;
  final String userId;
  final DateTime createdAt;
  final double totalPrice;
  final int itemCount;

  Order({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.totalPrice,
    required this.itemCount,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      userId: json['userId'],
      // Firestore sends a Timestamp, which we convert to a DateTime
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      itemCount: json['itemCount'],
    );
  }
} 