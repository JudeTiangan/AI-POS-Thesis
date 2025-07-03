class Item {
  final String? id;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String? barcode;
  final String? imageUrl;
  final int quantity; // Available stock quantity

  Item({
    this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.categoryId,
    this.barcode,
    this.imageUrl,
    this.quantity = 0, // Default to 0 stock
  });

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      price: (json['price'] as num).toDouble(),
      categoryId: json['categoryId'],
      barcode: json['barcode'],
      imageUrl: json['imageUrl'],
      quantity: json['quantity'] ?? 0, // Handle missing quantity field
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'categoryId': categoryId,
      'barcode': barcode,
      'imageUrl': imageUrl,
      'quantity': quantity,
    };
  }

  // Helper method to check if item is in stock
  bool get isInStock => quantity > 0;
  
  // Helper method to check if item has low stock (less than 5)
  bool get isLowStock => quantity > 0 && quantity < 5;
  
  // Helper method to check if out of stock
  bool get isOutOfStock => quantity <= 0;
} 