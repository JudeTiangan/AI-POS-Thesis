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
          key: ValueKey('image_${item.id}'), // Add unique key for caching
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.broken_image, size: 40);
          },
        );
      } else {
        // Fallback to network image for any non-base64 images
        return Image.network(
          item.imageUrl!,
          key: ValueKey('image_${item.id}'), // Add unique key for caching
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
          
          // Large image section (most of the card)
          Expanded(
            flex: 5, // Give image most of the space
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              child: _buildItemImage(),
            ),
          ),
          
          // Very compact text content section
          Expanded(
            flex: 1, // Minimal space for text, just enough for essentials
            child: Padding(
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
                  
                  // Very compact add button
                  SizedBox(
                    width: double.infinity,
                    height: 20,
                    child: ElevatedButton(
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
                        textStyle: const TextStyle(fontSize: 9),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 