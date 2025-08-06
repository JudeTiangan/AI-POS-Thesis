import 'package:flutter/material.dart';
import 'package:frontend/models/item.dart';
import 'package:frontend/services/cart_service.dart';
import 'package:frontend/widgets/product_image_widget.dart';

class ItemCard extends StatelessWidget {
  final Item item;

  const ItemCard({super.key, required this.item});

  // Helper method to build image widget using ProductImageWidget
  Widget _buildItemImage() {
    return ProductCardImage(
      imageUrl: item.imageUrl,
      height: 80,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartService = CartService();

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stock indicator at the top
          if (item.isOutOfStock)
            Container(
              color: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: const Text(
                'OUT OF STOCK',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            )
          else if (item.isLowStock)
            Container(
              color: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                'LOW STOCK ( {item.quantity})',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          // Large image section (most of the card)
          Expanded(
            flex: 5, // Give image most of the space
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              child: _buildItemImage(),
            ),
          ),
          // Text and Add button section (fixed height)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product name (single line)
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Price and stock in one line
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₱${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    if (item.isInStock)
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(fontSize: 8, color: Colors.grey),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                // Add button (always visible if in stock)
                SizedBox(
                  width: double.infinity,
                  height: 28, // Increased height for easier tapping on mobile
                  child: item.isInStock
                      ? ElevatedButton(
                          onPressed: () {
                            try {
                              cartService.addItem(item, quantity: 1);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${item.name} added to cart'),
                                  duration: const Duration(seconds: 1),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add ${item.name}: $e'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                            textStyle: const TextStyle(fontSize: 11),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Add'),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 