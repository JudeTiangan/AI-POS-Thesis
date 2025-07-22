import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/cart_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/models/cart_item.dart';
import 'package:frontend/models/order.dart';
import 'package:frontend/services/order_service.dart';
import 'package:frontend/services/payment_service.dart';
import 'package:frontend/screens/receipt_screen.dart';
import 'package:frontend/widgets/recommendations_widget.dart';
import 'package:frontend/widgets/product_image_widget.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService cartService = CartService();
  final AuthService authService = AuthService();
  
  // Checkout form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Delivery address controllers
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _landmarksController = TextEditingController();
  final _deliveryInstructionsController = TextEditingController();
  
  OrderType _selectedOrderType = OrderType.pickup;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  bool _isProcessingOrder = false;
  bool _showCheckoutForm = false;
  Order? _currentOrder;
  String? _currentPaymentSourceId;

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  void _initializeUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _landmarksController.dispose();
    _deliveryInstructionsController.dispose();
    super.dispose();
  }

  // Helper method to build image widget for cart items
  Widget _buildItemImage(String? imageUrl) {
    return ProductThumbnail(
      imageUrl: imageUrl,
      size: 60,
      borderRadius: BorderRadius.circular(8),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shopping Cart',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFF8C00),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ValueListenableBuilder<List<CartItem>>(
        valueListenable: cartService.cart,
        builder: (context, cartItems, child) {
          if (cartItems.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add some items to get started!',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: _showCheckoutForm ? _buildCheckoutForm() : _buildCartListWithRecommendations(cartItems),
              ),
              _buildBottomSection(cartItems),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCartList(List<CartItem> cartItems) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final cartItem = cartItems[index];
                    return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
            padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                // Item image or placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: _buildItemImage(cartItem.item.imageUrl),
                ),
                const SizedBox(width: 16),
                
                // Item details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                        cartItem.item.name,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                        '₱${cartItem.item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFFF8C00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                                  Text(
                                    'Total: ₱${cartItem.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                
                // Quantity controls
                Row(
                              children: [
                    IconButton(
                      onPressed: () {
                        if (cartItem.item.id != null) {
                          cartService.decreaseQuantity(cartItem.item.id!);
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                      color: const Color(0xFFFF8C00),
                    ),
                                Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[300]!),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                        child: Text(
                                          '${cartItem.quantity}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                                  onPressed: () {
                        if (cartItem.item.id != null) {
                          cartService.increaseQuantity(cartItem.item.id!);
                        }
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      color: const Color(0xFFFF8C00),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
    );
  }

  Widget _buildCartListWithRecommendations(List<CartItem> cartItems) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Cart Items List
          ListView.builder(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cartItems.length,
            itemBuilder: (context, index) {
              final cartItem = cartItems[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Item image or placeholder
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[200],
                        ),
                        child: _buildItemImage(cartItem.item.imageUrl),
                      ),
                      const SizedBox(width: 16),
                      
                      // Item details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cartItem.item.name,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱${cartItem.item.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFFFF8C00),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Total: ₱${cartItem.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      
                      // Quantity controls
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (cartItem.item.id != null) {
                                cartService.decreaseQuantity(cartItem.item.id!);
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                            color: const Color(0xFFFF8C00),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${cartItem.quantity}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (cartItem.item.id != null) {
                                cartService.increaseQuantity(cartItem.item.id!);
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            color: const Color(0xFFFF8C00),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // AI Recommendations Section
          const Divider(thickness: 1, color: Colors.grey),
          RecommendationsWidget(
            currentCart: cartItems.map((cartItem) => cartItem.item).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCheckoutForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back to cart button
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showCheckoutForm = false;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                const Text(
                  'Checkout Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Customer Information
            _buildSectionTitle('Customer Information'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('Full Name *'),
              validator: (value) => value?.isEmpty ?? true ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: _inputDecoration('Email *'),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Order Type Selection
            _buildSectionTitle('Order Type'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<OrderType>(
                    title: const Text('Pickup'),
                    subtitle: const Text('Pick up at store'),
                    value: OrderType.pickup,
                    groupValue: _selectedOrderType,
                    onChanged: (OrderType? value) {
                      setState(() {
                        _selectedOrderType = value!;
                      });
                    },
                    activeColor: const Color(0xFFFF8C00),
                  ),
                ),
                Expanded(
                  child: RadioListTile<OrderType>(
                    title: const Text('Delivery'),
                    subtitle: const Text('Deliver to address'),
                    value: OrderType.delivery,
                    groupValue: _selectedOrderType,
                    onChanged: (OrderType? value) {
                      setState(() {
                        _selectedOrderType = value!;
                      });
                    },
                    activeColor: const Color(0xFFFF8C00),
                  ),
                ),
              ],
            ),

            // Delivery Address (if delivery is selected)
            if (_selectedOrderType == OrderType.delivery) ...[
              const SizedBox(height: 24),
              _buildSectionTitle('Delivery Address'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _streetController,
                decoration: _inputDecoration('Street Address *'),
                validator: (value) => _selectedOrderType == OrderType.delivery && (value?.isEmpty ?? true)
                    ? 'Street address is required for delivery' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: _inputDecoration('City *'),
                      validator: (value) => _selectedOrderType == OrderType.delivery && (value?.isEmpty ?? true)
                          ? 'City is required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _provinceController,
                      decoration: _inputDecoration('Province *'),
                      validator: (value) => _selectedOrderType == OrderType.delivery && (value?.isEmpty ?? true)
                          ? 'Province is required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _postalCodeController,
                      decoration: _inputDecoration('Postal Code *'),
                      keyboardType: TextInputType.number,
                      validator: (value) => _selectedOrderType == OrderType.delivery && (value?.isEmpty ?? true)
                          ? 'Postal code is required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _landmarksController,
                      decoration: _inputDecoration('Landmarks (Optional)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Mobile Phone Number *',
                  hintText: '+63 912 345 6789',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2),
                  ),
                  prefixIcon: const Icon(Icons.phone_android),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (_selectedOrderType == OrderType.delivery) {
                    if (value?.isEmpty ?? true) {
                      return 'Mobile phone number is required for delivery';
                    }
                    // Basic Philippine mobile number validation
                    final cleanedValue = value!.replaceAll(RegExp(r'[\s-\(\)]'), '');
                    if (!RegExp(r'^(\+63|0)(9\d{9}|\d{10})$').hasMatch(cleanedValue)) {
                      return 'Please enter a valid Philippine mobile number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Delivery Instructions
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: TextFormField(
                  controller: _deliveryInstructionsController,
                  decoration: InputDecoration(
                    labelText: 'Delivery Instructions (Optional)',
                    hintText: 'e.g., "Please deliver between 2-4 PM" or "Call before delivery"',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2),
                    ),
                    prefixIcon: const Icon(Icons.notes, color: Color(0xFFFF8C00)),
                    filled: true,
                    fillColor: Colors.transparent,
                  ),
                  maxLines: 3,
                  maxLength: 200,
                  keyboardType: TextInputType.multiline,
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Payment Method Selection
            _buildSectionTitle('Payment Method'),
            const SizedBox(height: 16),
            RadioListTile<PaymentMethod>(
              title: const Text('Cash'),
              subtitle: Text(_selectedOrderType == OrderType.pickup 
                  ? 'Pay when picking up' 
                  : 'Pay when delivered'),
              value: PaymentMethod.cash,
              groupValue: _selectedPaymentMethod,
              onChanged: (PaymentMethod? value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                });
              },
              activeColor: const Color(0xFFFF8C00),
            ),
            RadioListTile<PaymentMethod>(
              title: const Text('GCash'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pay online with GCash'),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      'Minimum amount: ₱20.00',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              value: PaymentMethod.gcash,
              groupValue: _selectedPaymentMethod,
              onChanged: (PaymentMethod? value) {
                // Check minimum amount before allowing selection
                final currentTotal = cartService.totalPrice.value;
                if (currentTotal < 20.0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('GCash payments require a minimum of ₱20.00. Current total: ₱${currentTotal.toStringAsFixed(2)}'),
                      backgroundColor: Colors.orange,
                      action: SnackBarAction(
                        label: 'OK',
                        textColor: Colors.white,
                        onPressed: () {},
                      ),
                    ),
                  );
                  return;
                }
                setState(() {
                  _selectedPaymentMethod = value!;
                });
              },
              activeColor: const Color(0xFFFF8C00),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFF8C00),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFFF8C00), width: 2),
      ),
    );
  }

  Widget _buildBottomSection(List<CartItem> cartItems) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
                child: Column(
                  children: [
          ValueListenableBuilder<double>(
            valueListenable: cartService.totalPrice,
            builder: (context, totalPrice, child) {
              return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                        'Total: ₱${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                        '${cartService.totalItemCount} items',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (!_showCheckoutForm)
                    ElevatedButton(
                      onPressed: cartItems.isEmpty ? null : () {
                        setState(() {
                          _showCheckoutForm = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Checkout', style: TextStyle(fontSize: 16)),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isProcessingOrder ? null : _processOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isProcessingOrder 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Place Order', style: TextStyle(fontSize: 16)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _processOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isProcessingOrder = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final cartItems = cartService.getCartItems();
      final totalPrice = cartService.totalPrice.value;
      
      // Validate payment amount for GCash
      if (_selectedPaymentMethod == PaymentMethod.gcash) {
        final validation = PaymentService.validatePaymentAmount(totalPrice, 'gcash');
        if (!(validation['isValid'] ?? false)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(validation['error'] ?? 'Payment validation failed'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
          return;
        }
      }

      // Convert cart items to order items format
      final orderItems = cartItems.map((cartItem) => OrderItem(
        itemId: cartItem.item.id ?? '',
        itemName: cartItem.item.name,
        price: cartItem.item.price,
        quantity: cartItem.quantity,
        itemImageUrl: cartItem.item.imageUrl,
      )).toList();

      DeliveryAddress? deliveryAddress;
      if (_selectedOrderType == OrderType.delivery) {
        deliveryAddress = DeliveryAddress(
          street: _streetController.text.trim(),
          city: _cityController.text.trim(),
          province: _provinceController.text.trim(),
          postalCode: _postalCodeController.text.trim(),
          contactNumber: _phoneController.text.trim(),
          landmarks: _landmarksController.text.trim().isNotEmpty 
              ? _landmarksController.text.trim() 
              : null,
        );
      }

      // Get delivery instructions for delivery orders
      String? deliveryInstructions;
      if (_selectedOrderType == OrderType.delivery) {
        final instructionsText = _deliveryInstructionsController.text.trim();
        deliveryInstructions = instructionsText.isNotEmpty ? instructionsText : null;
      }

      // Create order with new service method
      final result = await OrderService.createOrder(
        userId: user.uid,
        items: orderItems,
        totalPrice: totalPrice,
        orderType: _selectedOrderType,
        paymentMethod: _selectedPaymentMethod,
        deliveryAddress: deliveryAddress,
        deliveryInstructions: deliveryInstructions,
        customerName: _nameController.text.trim().isNotEmpty 
          ? _nameController.text.trim() 
          : 'Customer',
        customerEmail: _emailController.text.trim().isNotEmpty 
          ? _emailController.text.trim() 
          : 'customer@example.com',
        customerPhone: _phoneController.text.trim().isNotEmpty 
          ? _phoneController.text.trim() 
          : null,
      );

      if (result['success']) {
        // Store the order object
        _currentOrder = result['order'];
        
        // Handle GCash payment
        if (result['paymentUrl'] != null) {
          // Show GCash payment dialog
          _showGCashPaymentDialog(
            result['paymentUrl'] as String, 
            _currentOrder!.id, 
            result['paymentSourceId'] as String? ?? ''
          );
        } else {
          // Cash payment or order creation successful
          _showSuccessAndNavigate(_currentOrder!.id, _currentOrder!);
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to create order');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isProcessingOrder = false;
      });
    }
  }

  void _showGCashPaymentDialog(String paymentUrl, String orderId, String paymentSourceId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 8),
            Text('GCash Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code,
              size: 64,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
              'Complete your payment using GCash',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('Order ID: ${orderId.substring(0, 8)}', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Amount: ₱${cartService.totalPrice.value.toStringAsFixed(2)}'),
                ],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                'REAL PAYMONGO INTEGRATION\nClick "Open GCash" to complete payment in your browser',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Cancel payment and delete order
              _cancelPayment(orderId);
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _processRealGCashPayment(paymentUrl, orderId, paymentSourceId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Open GCash'),
          ),
        ],
      ),
    );
  }

  Future<void> _processRealGCashPayment(String paymentUrl, String orderId, String paymentSourceId) async {
    try {
      // Store payment source ID for polling
      _currentPaymentSourceId = paymentSourceId;
      
      // Open payment URL in browser
      final urlOpened = await PaymentService.openPaymentUrl(paymentUrl);
      
      if (!urlOpened) {
        _showErrorMessage('Failed to open payment page. Please try again.');
        return;
      }

      // Show test payment completion dialog
      _showTestPaymentCompletionDialog(orderId);
      
    } catch (e) {
      _showErrorMessage('Error processing payment: $e');
    }
  }

  void _showPaymentMonitoringDialog(String orderId, String paymentSourceId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                CircularProgressIndicator(strokeWidth: 2),
                SizedBox(width: 12),
                Text('Waiting for Payment'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
                      children: [
                Text(
                  'Please complete your payment in the browser.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'This dialog will automatically close when payment is confirmed.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange),
                      SizedBox(height: 8),
                      Text(
                        'Do not close this app until payment is complete',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                          ),
                      ],
                    ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _cancelPayment(orderId);
                },
                child: Text('Cancel Payment'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Check payment status manually
                  await _checkPaymentStatusManually(orderId, paymentSourceId);
                },
                child: Text('Check Status'),
              ),
            ],
          );
        },
      ),
    );

    // Start automated polling
    _startPaymentPolling(orderId, paymentSourceId);
  }

  Future<void> _startPaymentPolling(String orderId, String paymentSourceId) async {
    try {
      final result = await PaymentService.pollPaymentStatus(
        paymentSourceId: paymentSourceId,
        maxAttempts: 60, // 5 minutes
        interval: Duration(seconds: 5),
      );

      // Close monitoring dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (result['success']) {
        // Payment successful
        _showPaymentSuccessDialog(orderId);
      } else {
        // Payment failed or timeout
        final errorMessage = result['error'] ?? 'Payment failed';
        print('❌ Payment polling failed: $errorMessage');
        
        // Check if it's a "resource not found" error - this might mean payment is still processing
        if (errorMessage.contains('resource_not_found') || errorMessage.contains('No such source')) {
          _showPaymentTimeoutDialog(orderId);
        } else {
          _showPaymentFailureDialog(orderId, errorMessage);
        }
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      _showErrorMessage('Error monitoring payment: $e');
    }
  }

  Future<void> _checkPaymentStatusManually(String orderId, String paymentSourceId) async {
    try {
      print('🔍 Manual payment status check for: $paymentSourceId');
      final result = await PaymentService.checkPaymentStatus(paymentSourceId);
      
      print('💳 Manual check result: $result');
      
      if (result['success']) {
        final status = result['status'];
        final message = PaymentService.getPaymentStatusMessage(status);
        
        if (status == 'succeeded' || status == 'chargeable' || status == 'consumed') {
          Navigator.of(context).pop(); // Close monitoring dialog
          _showPaymentSuccessDialog(orderId);
        } else if (status == 'failed' || status == 'cancelled' || status == 'expired') {
          Navigator.of(context).pop(); // Close monitoring dialog
          _showPaymentFailureDialog(orderId, message);
        } else {
          // Still processing
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        final errorMessage = result['error'] ?? 'Failed to check payment status';
        print('❌ Payment status check failed: $errorMessage');
        _showErrorMessage('Payment check failed: $errorMessage');
      }
    } catch (e) {
      print('❌ Error during manual payment check: $e');
      _showErrorMessage('Error checking payment: $e');
    }
  }

  void _showPaymentSuccessDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.celebration, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Your GCash payment has been confirmed!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Order ID: ${orderId.substring(0, 8)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Text(
              'Amount: ₱${cartService.totalPrice.value.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear cart and navigate to receipt
              cartService.clearCart();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptScreen(
                    order: _currentOrder!,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('View Receipt'),
          ),
        ],
      ),
    );
  }

  void _showTestPaymentCompletionDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.open_in_browser, color: Colors.blue),
            SizedBox(width: 8),
            Text('PayMongo Payment Opened'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'PayMongo payment page has been opened in your browser!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Complete the test payment process, then click "Payment Completed" below.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order ID:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(orderId.substring(0, 8)),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('₱${cartService.totalPrice.value.toStringAsFixed(2)}'),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '✅ REAL PayMongo Integration - Test Mode',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isProcessingOrder = false;
                _showCheckoutForm = false;
              });
            },
            child: Text('Cancel Order'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear cart and show success
              cartService.clearCart();
              _showPaymentSuccessDialog(orderId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Payment Completed'),
          ),
        ],
      ),
    );
  }

  void _showTestPaymentDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 8),
            Text('Test Payment Initiated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_browser, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text(
              'Your test payment has been sent to PayMongo!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'Complete the payment in your browser, then return here.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Order ID: ${orderId.substring(0, 8)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Amount: ₱${cartService.totalPrice.value.toStringAsFixed(2)}'),
                  SizedBox(height: 8),
                  Text(
                    'This is a test payment - no real money will be charged',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isProcessingOrder = false;
                _showCheckoutForm = false;
              });
            },
            child: Text('Create New Order'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear cart and show success
              cartService.clearCart();
              _showPaymentSuccessDialog(orderId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Mark as Paid (Test)'),
          ),
        ],
      ),
    );
  }

  void _showPaymentTimeoutDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange),
            SizedBox(width: 8),
            Text('Payment Status Unknown'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment_outlined, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'We couldn\'t verify your payment status immediately.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12),
            Text(
              'If you completed the payment in your browser, it may take a few minutes to process.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Order ID: ${orderId.substring(0, 8)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Keep this for reference'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isProcessingOrder = false;
                _showCheckoutForm = false;
              });
            },
            child: Text('Create New Order'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to main screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPaymentFailureDialog(String orderId, String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Payment Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment_outlined, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              errorMessage,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Your order has been cancelled.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isProcessingOrder = false;
                _showCheckoutForm = false;
              });
            },
            child: Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to main screen
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelPayment(String orderId) async {
    try {
      // In a real implementation, you might want to call an API to cancel the order
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment cancelled'),
          backgroundColor: Colors.red,
        ),
      );
      
      setState(() {
        _isProcessingOrder = false;
        _showCheckoutForm = false;
      });
    } catch (e) {
      print('Error cancelling payment: $e');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessAndNavigate(String orderId, Order order) {
    // Clear the cart
    cartService.clearCart();
    
    // Navigate to receipt screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptScreen(
          order: order,
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message, String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear cart and navigate to receipt
              cartService.clearCart();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptScreen(
                    order: _currentOrder!,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('View Receipt'),
          ),
        ],
      ),
    );
  }
} 