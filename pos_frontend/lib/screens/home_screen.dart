import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:frontend/models/item.dart';
import 'package:frontend/models/cart_item.dart';
import 'package:frontend/models/category.dart';
import 'package:frontend/services/item_service.dart';
import 'package:frontend/services/cart_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/category_service.dart';
import 'package:frontend/widgets/item_card.dart';
import 'package:frontend/screens/cart_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _itemsFuture = _itemService.getItems();
    _categoriesFuture = _categoryService.getCategories();
    _loadData();
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
      final items = await _itemService.getItems();
      final categories = await _categoryService.getCategories();
      
      setState(() {
        _allItems = items;
        _categories = categories;
        _applyFilters(); // Apply current filters to new data
      });
    } catch (e) {
      print('Error loading data: $e');
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

  Future<void> _scanBarcode() async {
    try {
      String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 'Cancel', true, ScanMode.BARCODE);

      if (barcodeScanRes != '-1') {
        final Item? item = await _itemService.getItemByBarcode(barcodeScanRes);
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
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to scan barcode: $e')),
      );
    }
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
          return Badge(
            label: Text(totalItemCount.toString()),
            isLabelVisible: totalItemCount > 0,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const CartScreen()));
              },
              child: const Icon(Icons.shopping_cart),
            ),
          );
        },
      ),
    );
  }
} 