import 'package:frontend/models/item.dart';

class CartItem {
  final Item item;
  final int quantity; // How many of this item in the cart

  CartItem({
    required this.item,
    required this.quantity,
  });

  // Calculate total price for this cart item (item price * quantity)
  double get totalPrice => item.price * quantity;

  // Create a copy with updated quantity
  CartItem copyWith({int? quantity}) {
    return CartItem(
      item: item,
      quantity: quantity ?? this.quantity,
    );
  }

  // Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'id': item.id,
      'name': item.name,
      'price': item.price,
      'quantity': quantity,
      'categoryId': item.categoryId,
      'barcode': item.barcode,
    };
  }

  // Create from JSON
  factory CartItem.fromJson(Map<String, dynamic> json, Item item) {
    return CartItem(
      item: item,
      quantity: json['quantity'] ?? 1,
    );
  }
} 