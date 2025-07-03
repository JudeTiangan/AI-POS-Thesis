import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:frontend/models/item.dart';
import 'package:frontend/models/cart_item.dart';
import 'package:frontend/services/item_service.dart';
import 'package:frontend/services/cart_service.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/widgets/item_card.dart';
import 'package:frontend/screens/cart_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ItemService _itemService = ItemService();
  final CartService _cartService = CartService();
  final AuthService _authService = AuthService();
  late Future<List<Item>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _itemService.getItems();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome!'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scanBarcode,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              // AuthWrapper will handle navigation
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Item>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No items available.'));
          }

          final items = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(10.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // Increase columns for desktop
              crossAxisSpacing: 10.0, // Horizontal space between cards
              mainAxisSpacing: 10.0, // Vertical space between cards
              childAspectRatio: 0.85, // Adjust ratio for better desktop viewing
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return ItemCard(item: items[index]);
            },
          );
        },
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