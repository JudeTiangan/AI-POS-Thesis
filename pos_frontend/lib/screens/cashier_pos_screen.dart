import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/models/item.dart';
import 'package:frontend/models/cart_item.dart';
import 'package:frontend/models/category.dart';
import 'package:frontend/models/order.dart';
import 'package:frontend/services/item_service.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/services/cart_service.dart';
import 'package:frontend/services/order_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/screens/receipt_screen.dart';
import 'package:frontend/widgets/product_image_widget.dart';

class CashierPOSScreen extends StatefulWidget {
  const CashierPOSScreen({super.key});

  @override
  State<CashierPOSScreen> createState() => _CashierPOSScreenState();
}

class _CashierPOSScreenState extends State<CashierPOSScreen> {
  final ItemService _itemService = ItemService();
  final CategoryService _categoryService = CategoryService();
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  final TextEditingController _customerNameController = TextEditingController();
  
  List<Item> _allItems = [];
  List<Item> _filteredItems = [];
  List<Category> _categories = [];
  List<CartItem> _currentOrder = [];
  String _selectedCategoryId = 'all';
  bool _isLoading = true;
  bool _isProcessingOrder = false;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _loadData();
    _customerNameController.text = 'Walk-in Customer';
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      final items = await _itemService.getItems();
      final categories = await _categoryService.getCategories();
      
      setState(() {
        _allItems = items;
        _filteredItems = items;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

  void _filterItemsByCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      if (categoryId == 'all') {
        _filteredItems = _allItems;
      } else {
        _filteredItems = _allItems.where((item) => item.categoryId == categoryId).toList();
      }
    });
  }

  void _addToOrder(Item item) {
    setState(() {
      final existingIndex = _currentOrder.indexWhere((cartItem) => cartItem.item.id == item.id);
      if (existingIndex >= 0) {
        _currentOrder[existingIndex] = CartItem(
          item: item,
          quantity: _currentOrder[existingIndex].quantity + 1,
        );
      } else {
        _currentOrder.add(CartItem(item: item, quantity: 1));
      }
    });
    
    // Haptic feedback
    HapticFeedback.lightImpact();
  }

  void _removeFromOrder(CartItem cartItem) {
    setState(() {
      if (cartItem.quantity > 1) {
        final index = _currentOrder.indexWhere((item) => item.item.id == cartItem.item.id);
        _currentOrder[index] = CartItem(
          item: cartItem.item,
          quantity: cartItem.quantity - 1,
        );
      } else {
        _currentOrder.removeWhere((item) => item.item.id == cartItem.item.id);
      }
    });
  }

  void _clearOrder() {
    setState(() {
      _currentOrder.clear();
      _customerNameController.text = 'Walk-in Customer';
    });
  }

  double get _totalAmount {
    return _currentOrder.fold(0.0, (sum, item) => sum + (item.item.price * item.quantity));
  }

  Future<void> _processOrder() async {
    if (_currentOrder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add items to the order')),
      );
      return;
    }

    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter customer name')),
      );
      return;
    }

    setState(() => _isProcessingOrder = true);

    try {
      // Get the current user (cashier)
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Not authenticated. Please log in again.');
      }

      final orderItems = _currentOrder.map((cartItem) => OrderItem(
        itemId: cartItem.item.id!,
        itemName: cartItem.item.name,
        quantity: cartItem.quantity,
        price: cartItem.item.price,
      )).toList();

      print('🔄 Creating POS order for user: ${currentUser.uid}');
      
      final result = await OrderService.createOrder(
        userId: currentUser.uid, // Use authenticated cashier's ID
        items: orderItems,
        totalPrice: _totalAmount,
        orderType: OrderType.pickup,
        paymentMethod: _selectedPaymentMethod,
        customerName: _customerNameController.text.trim(),
        customerEmail: 'pos@store.com',
      );

      if (result['success']) {
        final order = result['order'] as Order; // The order is already an Order object
        
        // Auto-complete walk-in orders since they're handled immediately
        print('🎯 Auto-completing walk-in order: ${order.id}');
        final statusUpdated = await OrderService.updateOrderStatus(
          orderId: order.id,
          orderStatus: OrderStatus.completed,
          adminNotes: 'Walk-in order completed by cashier ${_authService.currentUser?.email ?? "unknown"}',
        );
        
        // Also mark payment as completed for cash orders
        bool paymentUpdated = true;
        if (_selectedPaymentMethod == PaymentMethod.cash) {
          paymentUpdated = await OrderService.updatePaymentStatus(
            orderId: order.id,
            paymentStatus: PaymentStatus.paid,
            paymentTransactionId: 'CASH_${DateTime.now().millisecondsSinceEpoch}',
          );
        }
        
        if (statusUpdated && paymentUpdated) {
          print('✅ Walk-in order auto-completed successfully');
        } else {
          print('⚠️ Failed to auto-complete walk-in order, but order was created');
        }
        
        // Show success and navigate to receipt
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order processed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(order: order.copyWith(
              orderStatus: OrderStatus.completed, // Update the local order object for display
              paymentStatus: _selectedPaymentMethod == PaymentMethod.cash 
                  ? PaymentStatus.paid 
                  : order.paymentStatus,
              completedAt: DateTime.now(), // Mark completion time
            )),
          ),
        );
      } else {
        final errorMessage = result['message'] ?? 'Failed to process order';
        print('❌ Order creation failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('❌ Error in _processOrder: $e');
      
      String errorMessage = 'Error processing order';
      if (e.toString().contains('Not authenticated')) {
        errorMessage = 'Authentication error. Please log in again.';
      } else if (e.toString().contains('Network')) {
        errorMessage = 'Network error. Check your connection.';
      } else if (e.toString().contains('Failed to create order')) {
        errorMessage = 'Failed to create order. Please try again.';
      } else {
        errorMessage = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isProcessingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🛒 Cashier POS'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearOrder,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                // Left side - Items selection
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // Categories
                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _buildCategoryChip('all', 'All'),
                            ..._categories.map((category) => 
                              _buildCategoryChip(category.id!, category.name)),
                          ],
                        ),
                      ),
                      
                      // Items grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.9, // Slightly taller for better image display
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            return _buildItemCard(item);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Right side - Order summary
                Container(
                  width: 350,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: const Border(left: BorderSide(color: Colors.grey)),
                  ),
                  child: Column(
                    children: [
                      // Order header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.zero,
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.receipt, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Current Order',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Customer info
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                      ),
                      
                      // Order items
                      Expanded(
                        child: _currentOrder.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shopping_cart_outlined, 
                                         size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text('No items in order',
                                         style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _currentOrder.length,
                                itemBuilder: (context, index) {
                                  final cartItem = _currentOrder[index];
                                  return _buildOrderItemCard(cartItem);
                                },
                              ),
                      ),
                      
                      // Payment method
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Method:', 
                                       style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<PaymentMethod>(
                                    title: const Text('Cash'),
                                    value: PaymentMethod.cash,
                                    groupValue: _selectedPaymentMethod,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedPaymentMethod = value!;
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<PaymentMethod>(
                                    title: const Text('GCash'),
                                    value: PaymentMethod.gcash,
                                    groupValue: _selectedPaymentMethod,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedPaymentMethod = value!;
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<PaymentMethod>(
                                    title: const Text('PayPal'),
                                    value: PaymentMethod.paypal,
                                    groupValue: _selectedPaymentMethod,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedPaymentMethod = value!;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Total and checkout
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: Colors.grey[300]!)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total:',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '₱${_totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isProcessingOrder ? null : _processOrder,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                                child: _isProcessingOrder
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        'Process Order',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCategoryChip(String categoryId, String name) {
    final isSelected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(name),
        selected: isSelected,
        onSelected: (_) => _filterItemsByCategory(categoryId),
        backgroundColor: Colors.grey[200],
        selectedColor: Colors.teal[100],
        checkmarkColor: Colors.teal[700],
        labelStyle: TextStyle(
          color: isSelected ? Colors.teal[700] : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildItemCard(Item item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _addToOrder(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item image
              Expanded(
                child: ProductImageWidget(
                  imageUrl: item.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.contain, // Show full image without cropping
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '₱${item.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItemCard(CartItem cartItem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '₱${cartItem.item.price.toStringAsFixed(2)} each',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => _removeFromOrder(cartItem),
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                ),
                Text(
                  '${cartItem.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  onPressed: () => _addToOrder(cartItem.item),
                  icon: const Icon(Icons.add_circle, color: Colors.teal),
                ),
              ],
            ),
            Text(
              '₱${(cartItem.item.price * cartItem.quantity).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 