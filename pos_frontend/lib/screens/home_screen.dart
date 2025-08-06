import 'package:flutter/material.dart';

import 'package:frontend/models/item.dart';
import 'package:frontend/models/cart_item.dart';
import 'package:frontend/models/category.dart';
import 'package:frontend/services/item_service.dart';
import 'package:frontend/services/cart_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/services/order_service.dart';
import 'package:frontend/services/api_config.dart';
import 'package:frontend/models/order.dart';
import 'package:frontend/widgets/item_card.dart';
import 'package:frontend/screens/cart_screen.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ItemService _itemService = ItemService();
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  final CategoryService _categoryService = CategoryService();
  final TextEditingController _searchController = TextEditingController();
  
  late Future<List<Item>> _itemsFuture;
  late Future<List<Category>> _categoriesFuture;
  
  List<Item> _allItems = [];
  List<Item> _filteredItems = [];
  List<Category> _categories = [];
  String _selectedCategoryId = 'all'; // 'all' for showing all items
  String _searchQuery = '';
  Timer? _debounceTimer;
  bool _hasActiveOrders = false;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _itemService.getItems();
    _categoriesFuture = _categoryService.getCategories();
    _loadData();
    _checkForActiveOrders();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    // Cancel the previous timer
    _debounceTimer?.cancel();
    
    // Longer debounce time to reduce rebuilds
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
          _applyFilters();
        });
      }
    });
  }

  Future<void> _loadData() async {
    try {
      print('🔄 Loading data in HomeScreen...');
      final items = await _itemService.getItems();
      final categories = await _categoryService.getCategories();
      
      print('📦 Loaded ${items.length} items');
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        print('   📋 Item ${i + 1}: ${item.name}');
        print('      Image URL: ${item.imageUrl ?? "NULL"}');
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
          print('      ✅ Has image URL (${item.imageUrl!.length} chars)');
        } else {
          print('      ❌ No image URL');
        }
      }
      
      setState(() {
        _allItems = items;
        _categories = categories;
        _applyFilters(); // Apply current filters to new data
      });
      
      print('✅ Data loaded and state updated');
    } catch (e) {
      print('❌ Error loading data: $e');
    }
  }

  void _filterItemsByCategory(String categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Item> filtered = _allItems;

    // Apply category filter
    if (_selectedCategoryId != 'all') {
      filtered = filtered.where((item) => item.categoryId == _selectedCategoryId).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) =>
          item.name.toLowerCase().contains(_searchQuery) ||
          (item.description.toLowerCase().contains(_searchQuery) ?? false)
      ).toList();
    }

    _filteredItems = filtered;
  }



  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _applyFilters();
    });
  }

  // Check if user has active orders
  Future<void> _checkForActiveOrders() async {
    try {
      final orders = await OrderService.getUserOrders();
      final activeOrders = orders.where((order) => 
        order.orderStatus != OrderStatus.completed && 
        order.orderStatus != OrderStatus.cancelled
      ).toList();

      if (mounted) {
        setState(() {
          _hasActiveOrders = activeOrders.isNotEmpty;
        });
      }
    } catch (e) {
      // Silently fail - don't show errors during app initialization
      if (mounted) {
        setState(() {
          _hasActiveOrders = false;
        });
      }
    }
  }

  // Test API connectivity and authentication
  Future<void> _testApiConnectivity() async {
    print('🧪 === DEBUGGING API CONNECTIVITY ===');
    
    // Test 1: Check user authentication
    final user = _authService.currentUser;
    print('👤 Current user: ${user?.uid ?? 'NULL'}');
    print('📧 User email: ${user?.email ?? 'NULL'}');
    
    if (user == null) {
      print('❌ User is NOT authenticated');
      return;
    }
    
    // Test 2: Check API configuration
    print('🔗 Base URL: ${ApiConfig.baseUrl}');
    print('🔗 Orders URL: ${ApiConfig.ordersUrl}');
    print('🔗 Full URL: ${ApiConfig.ordersUrl}/user/${user.uid}');
    
    // Test 3: Check if backend server is running
    try {
      final pingResponse = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/items'),
        headers: {'Content-Type': 'application/json'},
      );
      print('🏥 Backend Health Check: ${pingResponse.statusCode}');
      if (pingResponse.statusCode != 200) {
        print('⚠️ Backend may be down or starting up');
      }
    } catch (pingError) {
      print('❌ Backend Connection Error: $pingError');
    }
    
    // Test 4: Try the user orders API call
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.ordersUrl}/user/${user.uid}'),
        headers: {'Content-Type': 'application/json'},
      );
      print('📡 HTTP Response Status: ${response.statusCode}');
      print('📡 HTTP Response Body: ${response.body}');
    } catch (httpError) {
      print('❌ HTTP Error: $httpError');
    }
  }

  // Show notification popup with order status
  void _showOrderNotifications() async {
    try {
      print('🔔 Fetching user orders for notifications...');
      
      // Run debugging first
      await _testApiConnectivity();
      
      final orders = await OrderService.getUserOrders();
      print('📋 Received ${orders.length} orders from API');
      
      final activeOrders = orders.where((order) => 
        order.orderStatus != OrderStatus.completed && 
        order.orderStatus != OrderStatus.cancelled
      ).toList();
      
      print('📋 Active orders: ${activeOrders.length}');

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.notifications, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text('Order Notifications'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: activeOrders.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No active orders',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your orders will appear here when you place them',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: activeOrders.length,
                      itemBuilder: (context, index) {
                        final order = activeOrders[index];
                        return _buildOrderNotificationCard(order);
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Refresh the notification indicator after closing
                  _checkForActiveOrders();
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print('❌ Error in _showOrderNotifications: $e');
      if (!mounted) return;
      
      // Still show the dialog but with error message
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700]),
                const SizedBox(width: 8),
                const Text('Notification Error'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unable to load notifications at the moment.'),
                const SizedBox(height: 8),
                Text(
                  'Error: $e',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please check:\n• Internet connection\n• Backend server status\n• User authentication',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showOrderNotifications(); // Retry
                },
                child: const Text('Retry'),
              ),
            ],
          );
        },
      );
    }
  }

  Widget _buildOrderNotificationCard(Order order) {
    Color statusColor = _getStatusColor(order.orderStatus);
    String statusMessage = _getStatusMessage(order.orderStatus, order.orderType);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.statusDisplayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Order #${order.id.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusMessage,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₱${order.totalPrice.toStringAsFixed(2)} • ${DateFormat('MMM dd, HH:mm').format(order.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.preparing:
        return Colors.blue;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.teal;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  String _getStatusMessage(OrderStatus status, OrderType orderType) {
    switch (status) {
      case OrderStatus.pending:
        return 'Your order has been received and is being confirmed.';
      case OrderStatus.preparing:
        return 'Your order is being prepared in the kitchen.';
      case OrderStatus.ready:
        return orderType == OrderType.pickup 
            ? 'Your order is ready for pickup!' 
            : 'Your order is ready for delivery!';
      case OrderStatus.completed:
        return 'Your order has been completed.';
      case OrderStatus.cancelled:
        return 'Your order has been cancelled.';
    }
  }

  Future<void> _scanBarcode() async {
    // Show dialog for manual barcode entry (camera scanning disabled for APK build)
    showDialog(
      context: context,
      builder: (context) {
        String barcodeInput = '';
        return AlertDialog(
          title: const Text('Enter Barcode'),
          content: TextField(
            onChanged: (value) => barcodeInput = value,
            decoration: const InputDecoration(
              hintText: 'Enter barcode manually',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                if (barcodeInput.isNotEmpty) {
                  try {
                    final Item? item = await _itemService.getItemByBarcode(barcodeInput);
                    if (item != null) {
                      _cartService.addItem(item);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${item.name} added to cart!')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Item not found for this barcode.')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategorySection() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          // "All" category chip
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: const Text('All'),
              selected: _selectedCategoryId == 'all',
              onSelected: (_) => _filterItemsByCategory('all'),
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue[700],
              labelStyle: TextStyle(
                color: _selectedCategoryId == 'all' ? Colors.blue[700] : Colors.grey[700],
                fontWeight: _selectedCategoryId == 'all' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // Category chips from admin panel
          ..._categories.map((category) => Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(category.name),
              selected: _selectedCategoryId == category.id,
              onSelected: (_) => _filterItemsByCategory(category.id!),
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.blue[100],
              checkmarkColor: Colors.blue[700],
              labelStyle: TextStyle(
                color: _selectedCategoryId == category.id ? Colors.blue[700] : Colors.grey[700],
                fontWeight: _selectedCategoryId == category.id ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search items...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSearch,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: const BorderSide(color: Colors.blue, width: 2.0),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh items and categories',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
            tooltip: 'Scan barcode',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              // AuthWrapper will handle navigation
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter section
          _buildCategorySection(),
          
          // Search bar
          _buildSearchBar(),
          
          // Divider
          const Divider(height: 1),
          
          // Items grid
          Expanded(
            child: _allItems.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _filteredItems.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.6,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _searchQuery.isNotEmpty ? Icons.search_off : Icons.category_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _searchQuery.isNotEmpty 
                                            ? 'No items found for "$_searchQuery"'
                                            : 'No items in this category',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'Try a different search term'
                                            : 'Try selecting a different category',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
                            key: ValueKey('grid_${_filteredItems.length}'),
                            padding: const EdgeInsets.all(10.0),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 6.0,
                              mainAxisSpacing: 6.0,  
                              childAspectRatio: 0.8,
                            ),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              return ItemCard(
                                key: ValueKey('item_${item.id}'),
                                item: item,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: ValueListenableBuilder<List<CartItem>>(
        valueListenable: _cartService.cart,
        builder: (context, cartItems, child) {
          final totalItemCount = _cartService.totalItemCount;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification Bell - 1 inch above the cart
              Container(
                margin: const EdgeInsets.only(bottom: 72), // 1 inch spacing (72 pixels ≈ 1 inch)
                child: FloatingActionButton(
                  mini: true, // Smaller size for notification bell
                  backgroundColor: Colors.blue[600],
                  onPressed: _showOrderNotifications,
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.notifications,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      // Red dot indicator for active orders
                      if (_hasActiveOrders)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Cart FloatingActionButton
              Badge(
                label: Text(totalItemCount.toString()),
                isLabelVisible: totalItemCount > 0,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CartScreen()));
                  },
                  child: const Icon(Icons.shopping_cart),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

 