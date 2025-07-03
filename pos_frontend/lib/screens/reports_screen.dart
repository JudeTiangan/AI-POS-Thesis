import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<Map<String, dynamic>> _reportsFuture;

  @override
  void initState() {
    super.initState();
    _reportsFuture = _loadReportsData();
  }

  Future<Map<String, dynamic>> _loadReportsData() async {
    try {
      // Get all orders
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get();

      // Get all order items
      final orderItemsSnapshot = await FirebaseFirestore.instance
          .collection('orderItems')
          .get();

      // Get all items for reference
      final itemsSnapshot = await FirebaseFirestore.instance
          .collection('items')
          .get();

      // Create item lookup map
      Map<String, Map<String, dynamic>> itemsMap = {};
      for (var doc in itemsSnapshot.docs) {
        itemsMap[doc.id] = {
          'name': doc.data()['name'],
          'price': doc.data()['price'],
        };
      }

      // Calculate statistics
      double totalRevenue = 0;
      int totalOrders = ordersSnapshot.docs.length;
      Map<String, int> itemQuantitySold = {};
      Map<String, double> itemRevenue = {};
      List<Map<String, dynamic>> recentOrders = [];

      // Process orders
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        totalRevenue += (orderData['totalPrice'] as num).toDouble();
        
        // Add to recent orders (limit to 10)
        if (recentOrders.length < 10) {
          recentOrders.add({
            'id': orderDoc.id,
            'totalPrice': orderData['totalPrice'],
            'createdAt': orderData['createdAt'],
            'itemCount': orderData['itemCount'] ?? 0,
          });
        }
      }

      // Process order items for quantity tracking
      for (var orderItemDoc in orderItemsSnapshot.docs) {
        final itemData = orderItemDoc.data();
        final itemId = itemData['itemId'];
        final itemName = itemData['itemName'];
        final price = (itemData['price'] as num).toDouble();
        
        // Count quantities (assuming each order item doc represents 1 quantity)
        itemQuantitySold[itemName] = (itemQuantitySold[itemName] ?? 0) + 1;
        itemRevenue[itemName] = (itemRevenue[itemName] ?? 0) + price;
      }

      // Get popular items (top 5 by quantity sold)
      var popularItems = itemQuantitySold.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      popularItems = popularItems.take(5).toList();

      // Get top revenue items (top 5 by revenue)
      var topRevenueItems = itemRevenue.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      topRevenueItems = topRevenueItems.take(5).toList();

      return {
        'totalRevenue': totalRevenue,
        'totalOrders': totalOrders,
        'totalItemsSold': itemQuantitySold.values.fold(0, (sum, qty) => sum + qty),
        'popularItems': popularItems,
        'topRevenueItems': topRevenueItems,
        'recentOrders': recentOrders,
        'allItemsSold': itemQuantitySold,
      };
    } catch (e) {
      print('Error loading reports data: $e');
      throw e;
    }
  }

  Future<void> _refreshReports() async {
    setState(() {
      _reportsFuture = _loadReportsData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Sales Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshReports,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshReports,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _reportsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshReports,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Revenue',
                          '₱${data['totalRevenue'].toStringAsFixed(2)}',
                          Icons.monetization_on,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Orders',
                          '${data['totalOrders']}',
                          Icons.shopping_cart,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Items Sold',
                          '${data['totalItemsSold']}',
                          Icons.inventory,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSummaryCard(
                          'Avg Order',
                          data['totalOrders'] > 0 
                              ? '₱${(data['totalRevenue'] / data['totalOrders']).toStringAsFixed(2)}'
                              : '₱0.00',
                          Icons.calculate,
                          Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Popular Items by Quantity
                  _buildSectionTitle('🔥 Popular Items (by Quantity Sold)'),
                  const SizedBox(height: 8),
                  _buildPopularItemsList(data['popularItems']),
                  
                  const SizedBox(height: 24),

                  // Top Revenue Items
                  _buildSectionTitle('💰 Top Revenue Items'),
                  const SizedBox(height: 8),
                  _buildTopRevenueList(data['topRevenueItems']),

                  const SizedBox(height: 24),

                  // All Items Sold
                  _buildSectionTitle('📋 All Items Sold'),
                  const SizedBox(height: 8),
                  _buildAllItemsList(data['allItemsSold']),

                  const SizedBox(height: 24),

                  // Recent Orders
                  _buildSectionTitle('🕒 Recent Orders'),
                  const SizedBox(height: 8),
                  _buildRecentOrdersList(data['recentOrders']),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildPopularItemsList(List<MapEntry<String, int>> items) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No sales data available.'),
        ),
      );
    }

    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange,
              child: Text('${index + 1}'),
            ),
            title: Text(item.key),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${item.value} sold',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopRevenueList(List<MapEntry<String, double>> items) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No revenue data available.'),
        ),
      );
    }

    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Text('${index + 1}'),
            ),
            title: Text(item.key),
            trailing: Text(
              '₱${item.value.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAllItemsList(Map<String, int> allItems) {
    if (allItems.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No items sold yet.'),
        ),
      );
    }

    final sortedItems = allItems.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sortedItems.length,
        itemBuilder: (context, index) {
          final item = sortedItems[index];
          return ListTile(
            title: Text(item.key),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${item.value}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentOrdersList(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No recent orders.'),
        ),
      );
    }

    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final createdAt = order['createdAt'] as Timestamp;
          final date = createdAt.toDate();
          
          return ListTile(
            leading: const Icon(Icons.receipt),
            title: Text('Order #${order['id'].substring(0, 8)}'),
            subtitle: Text('${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₱${order['totalPrice'].toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${order['itemCount']} items',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 