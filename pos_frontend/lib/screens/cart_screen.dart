import 'package:flutter/material.dart';
import 'package:frontend/services/cart_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/order_service.dart';
import 'package:frontend/widgets/recommendations_widget.dart';
import 'package:frontend/screens/receipt_screen.dart';
import 'package:frontend/models/item.dart';
import 'package:frontend/models/cart_item.dart';
import 'dart:convert';
import 'dart:typed_data';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();
  bool _isLoading = false;

  // Helper method to build image widget for cart items
  Widget _buildCartItemImage(Item item) {
    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return const Icon(Icons.image);
    }

    try {
      // Check if it's a base64 image (starts with data:)
      if (item.imageUrl!.startsWith('data:image') || item.imageUrl!.startsWith('data:application/octet-stream')) {
        final base64String = item.imageUrl!.split(',')[1];
        final Uint8List bytes = base64Decode(base64String);
        return CircleAvatar(
          backgroundImage: MemoryImage(bytes),
        );
      } else {
        // Fallback to network image for any non-base64 images
        return CircleAvatar(
          backgroundImage: NetworkImage(item.imageUrl!),
        );
      }
    } catch (e) {
      return const CircleAvatar(
        child: Icon(Icons.broken_image),
      );
    }
  }

  void _checkout() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('You must be logged in to check out.');
      }
      
      final List<Item> items = _cartService.getItemsForCheckout();
      final double totalPrice = _cartService.totalPrice.value;

      final String orderId = await _orderService.createOrder(
        userId: user.uid,
        items: items,
        totalPrice: totalPrice,
      );

      // Clear the cart
      _cartService.clearCart();

      // Navigate to receipt screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              items: items,
              totalPrice: totalPrice,
              orderId: orderId,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checkout failed: $e')),
      );
    } finally {
       if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
      ),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: _cartService.cart,
        builder: (context, cartItems, child) {
          if (cartItems.isEmpty && !_isLoading) {
            return const Center(
              child: Text('Your cart is empty.'),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final cartItem = cartItems[index];
                    final item = cartItem.item;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            // Product Image
                            _buildCartItemImage(item),
                            const SizedBox(width: 12),
                            // Product Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: Theme.of(context).textTheme.titleMedium,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₱${item.price.toStringAsFixed(2)} each',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total: ₱${cartItem.totalPrice.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Quantity Controls
                            Column(
                              children: [
                                // Quantity Display and Controls
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Decrease Button
                                      InkWell(
                                        onTap: () {
                                          _cartService.decreaseQuantity(item.id!);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: const Icon(Icons.remove, size: 16),
                                        ),
                                      ),
                                      // Quantity Display
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Text(
                                          '${cartItem.quantity}',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Increase Button
                                      InkWell(
                                        onTap: () {
                                          _cartService.increaseQuantity(item.id!);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: const Icon(Icons.add, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Remove Button
                                TextButton.icon(
                                  onPressed: () {
                                    _cartService.removeItem(item);
                                  },
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('Remove'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // --- Recommendations ---
              if (cartItems.isNotEmpty)
                RecommendationsWidget(currentCart: cartItems.map((cartItem) => cartItem.item).toList()),
              // --- Total and Checkout ---
              const Divider(thickness: 2),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Item Count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Items:',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${_cartService.totalItemCount}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Total Price
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ValueListenableBuilder(
                          valueListenable: _cartService.totalPrice,
                          builder: (context, total, child) => Text(
                            'Total: ₱${total.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isLoading)
                          const CircularProgressIndicator()
                        else
                          ElevatedButton(
                            onPressed: cartItems.isEmpty ? null : _checkout,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                              textStyle: const TextStyle(fontSize: 18)
                            ),
                            child: const Text('Checkout'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 