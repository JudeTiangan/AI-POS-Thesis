import 'package:flutter/material.dart';
import 'package:frontend/models/item.dart';
import 'package:frontend/services/cart_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class ItemCard extends StatelessWidget {
  final Item item;

  const ItemCard({super.key, required this.item});

  // Helper method to build image widget from base64 string
  Widget _buildItemImage() {
    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return const Icon(Icons.image_not_supported, size: 40, color: Colors.grey);
    }

    try {
      // Check if it's a base64 image (starts with data:)
      if (item.imageUrl!.startsWith('data:image') || item.imageUrl!.startsWith('data:application/octet-stream')) {
        final base64String = item.imageUrl!.split(',')[1];
        final Uint8List bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 40);
          },
        );
      } else {
        // Fallback to network image for any non-base64 images
        return Image.network(
          item.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 40);
          },
        );
      }
    } catch (e) {
      return const Icon(Icons.broken_image, size: 40);
    }
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
                'LOW STOCK (${item.quantity})',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          
          Expanded(
            flex: 3, // Give more controlled space to image
            child: Container(
              height: 120, // Fixed height for consistency
              child: _buildItemImage(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              item.name,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₱${item.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (item.isInStock)
                  Text(
                    'Stock: ${item.quantity}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart, size: 16),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(fontSize: 12),
                // backgroundColor: item.isOutOfStock ? Colors.grey : null,
              ),
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
            ),
          ),
        ],
      ),
    );
  }
} 