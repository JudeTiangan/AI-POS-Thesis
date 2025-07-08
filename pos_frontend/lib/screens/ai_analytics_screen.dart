import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/models/customer_analytics.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/ai_recommendation_service.dart';

class AIAnalyticsScreen extends StatefulWidget {
  const AIAnalyticsScreen({super.key});

  @override
  State<AIAnalyticsScreen> createState() => _AIAnalyticsScreenState();
}

class _AIAnalyticsScreenState extends State<AIAnalyticsScreen> {
  final AuthService _authService = AuthService();
  final AIRecommendationService _aiService = AIRecommendationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isLoading = true;
  CustomerAnalytics? _customerAnalytics;
  Map<String, dynamic> _globalAnalytics = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔄 Loading AI Analytics...');
      
      // Load global analytics (includes customer insights)
      await _loadGlobalAnalytics();
      
      // Load customer behavior patterns
      await _loadCustomerInsights();
      
    } catch (e) {
      print('❌ Error loading analytics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGlobalAnalytics() async {
    try {
      print('🔄 Loading global analytics...');
      
      // Get all orders directly from orders collection
      final ordersSnapshot = await _firestore.collection('orders').get();
      
      Map<String, int> globalItemFrequency = {};
      Map<String, double> globalCategoryPreferences = {};
      Set<String> allCustomers = {};
      int totalOrders = 0;
      double totalRevenue = 0.0;
      
      for (final doc in ordersSnapshot.docs) {
        final orderData = doc.data();
        final userId = orderData['userId'] as String?;
        final orderTotal = (orderData['totalPrice'] as num?)?.toDouble() ?? 0.0;
        final items = orderData['items'] as List?;
        
        if (userId != null) {
          allCustomers.add(userId);
        }
        
        totalOrders++;
        totalRevenue += orderTotal;
        
        // Process items in the order
        if (items != null) {
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final itemId = item['itemId'] as String?;
              final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
              
              if (itemId != null) {
                globalItemFrequency[itemId] = (globalItemFrequency[itemId] ?? 0) + quantity;
                
                // Try to get category for this item
                try {
                  final itemDoc = await _firestore.collection('items').doc(itemId).get();
                  if (itemDoc.exists) {
                    final itemData = itemDoc.data()!;
                    final categoryId = itemData['categoryId'] as String?;
                    if (categoryId != null) {
                      globalCategoryPreferences[categoryId] = (globalCategoryPreferences[categoryId] ?? 0.0) + quantity;
                    }
                  }
                } catch (e) {
                  print('Could not fetch category for item $itemId: $e');
                }
              }
            }
          }
        }
      }
      
      // Calculate association rules from orders
      final associationRules = await _calculateGlobalAssociationRules();
      
      _globalAnalytics = {
        'totalCustomers': allCustomers.length,
        'totalOrders': totalOrders,
        'totalRevenue': totalRevenue,
        'averageOrderValue': totalOrders > 0 ? totalRevenue / totalOrders : 0.0,
        'popularItems': globalItemFrequency,
        'categoryPreferences': globalCategoryPreferences,
        'associationRules': associationRules,
      };
      
      print('✅ Global analytics loaded: ${_globalAnalytics['totalOrders']} orders, ${_globalAnalytics['totalCustomers']} customers');
      
    } catch (e) {
      print('❌ Error loading global analytics: $e');
    }
  }

  Future<void> _loadCustomerInsights() async {
    try {
      print('👥 Loading customer behavior insights...');
      
      // First, let's check if there are any orders at all
      final ordersSnapshot = await _firestore.collection('orders').get();
      print('📋 Total orders in database: ${ordersSnapshot.docs.length}');
      
      // Get all customer analytics to understand customer behavior patterns
      final analyticsSnapshot = await _firestore.collection('customerAnalytics').get();
      print('📊 Customer analytics documents found: ${analyticsSnapshot.docs.length}');
      
      if (analyticsSnapshot.docs.isNotEmpty) {
        List<CustomerAnalytics> allCustomerAnalytics = [];
        
        for (final doc in analyticsSnapshot.docs) {
          try {
            print('🔍 Processing analytics for customer: ${doc.id}');
            final analytics = CustomerAnalytics.fromJson(doc.data());
            allCustomerAnalytics.add(analytics);
            print('✅ Analytics parsed successfully for ${doc.id}: ${analytics.totalOrders} orders');
          } catch (e) {
            print('❌ Error parsing customer analytics for ${doc.id}: $e');
          }
        }
        
        if (allCustomerAnalytics.isNotEmpty) {
          // Calculate aggregate customer insights
          _customerAnalytics = _calculateAggregateCustomerInsights(allCustomerAnalytics);
          print('✅ Customer insights calculated for ${allCustomerAnalytics.length} customers');
          print('📊 Aggregate stats: ${_customerAnalytics?.totalOrders} total orders, ${_customerAnalytics?.frequentItems.length} popular items');
        } else {
          print('⚠️ No valid customer analytics could be parsed');
          _customerAnalytics = null;
        }
      } else {
        print('📝 No customer analytics found in database');
        if (ordersSnapshot.docs.isNotEmpty) {
          print('⚠️ Warning: Orders exist but no analytics found - analytics may not be generating properly');
        }
        _customerAnalytics = null;
      }
      
    } catch (e) {
      print('❌ Error loading customer insights: $e');
      _customerAnalytics = null;
    }
  }

  CustomerAnalytics? _calculateAggregateCustomerInsights(List<CustomerAnalytics> allCustomers) {
    if (allCustomers.isEmpty) return null;
    
    // Aggregate data across all customers
    Map<String, int> totalItemFrequency = {};
    Map<String, double> totalCategoryPreferences = {};
    List<String> allFrequentItems = [];
    double totalAverageOrderValue = 0;
    int totalOrdersAllCustomers = 0;
    DateTime? mostRecentPurchase;
    
    for (final customer in allCustomers) {
      // Aggregate item frequencies
      customer.itemPurchaseFrequency.forEach((itemId, count) {
        totalItemFrequency[itemId] = (totalItemFrequency[itemId] ?? 0) + count;
      });
      
      // Aggregate category preferences
      customer.categoryPreferences.forEach((categoryId, preference) {
        totalCategoryPreferences[categoryId] = (totalCategoryPreferences[categoryId] ?? 0) + preference;
      });
      
      // Add frequent items
      allFrequentItems.addAll(customer.frequentItems);
      
      // Sum up order values and counts
      totalAverageOrderValue += customer.averageOrderValue * customer.totalOrders;
      totalOrdersAllCustomers += customer.totalOrders;
      
      // Find most recent purchase
      if (mostRecentPurchase == null || customer.lastPurchase.isAfter(mostRecentPurchase)) {
        mostRecentPurchase = customer.lastPurchase;
      }
    }
    
    // Calculate overall average order value
    final overallAverageOrderValue = totalOrdersAllCustomers > 0 
        ? totalAverageOrderValue / totalOrdersAllCustomers : 0.0;
    
    // Find most popular items across all customers
    final popularItems = totalItemFrequency.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    
    final topFrequentItems = popularItems.take(5).map((e) => e.key).toList();
    
    // Normalize category preferences
    final totalCategorySum = totalCategoryPreferences.values.fold(0.0, (sum, value) => sum + value);
    if (totalCategorySum > 0) {
      totalCategoryPreferences.forEach((key, value) {
        totalCategoryPreferences[key] = value / totalCategorySum;
      });
    }
    
    // Create aggregate customer insights
    return CustomerAnalytics(
      customerId: 'ALL_CUSTOMERS',
      itemPurchaseFrequency: totalItemFrequency,
      purchaseHistory: [], // Not needed for aggregate view
      categoryPreferences: totalCategoryPreferences,
      lastPurchase: mostRecentPurchase ?? DateTime.now(),
      averageOrderValue: overallAverageOrderValue,
      totalOrders: totalOrdersAllCustomers,
      frequentItems: topFrequentItems,
      associationRules: {}, // Will be calculated separately
    );
  }

  Future<List<Map<String, dynamic>>> _calculateGlobalAssociationRules() async {
    try {
      final ordersSnapshot = await _firestore.collection('orders').get();
      
      // Build transaction database from orders directly
      Map<String, List<String>> transactions = {};
      Map<String, String> itemNames = {}; // itemId -> itemName
      
      for (final orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final items = orderData['items'] as List?;
        
        if (items != null && items.isNotEmpty) {
          List<String> orderItems = [];
          
          for (final item in items) {
            if (item is Map<String, dynamic>) {
              final itemId = item['itemId'] as String?;
              final itemName = item['itemName'] as String?;
              
              if (itemId != null) {
                orderItems.add(itemId);
                if (itemName != null) {
                  itemNames[itemId] = itemName;
                }
              }
            }
          }
          
          if (orderItems.length > 1) { // Only include orders with multiple items
            transactions[orderDoc.id] = orderItems;
          }
        }
      }
      
      // Calculate association rules
      List<Map<String, dynamic>> rules = [];
      final itemIds = itemNames.keys.toList();
      
      for (int i = 0; i < itemIds.length && rules.length < 10; i++) {
        for (int j = i + 1; j < itemIds.length && rules.length < 10; j++) {
          final item1 = itemIds[i];
          final item2 = itemIds[j];
          
          final confidence = _calculateConfidence([item1], item2, transactions);
          final support = _calculateSupport([item1, item2], transactions);
          final lift = _calculateLift([item1], item2, transactions);
          
          if (confidence > 0.1 && support > 0.05) { // Minimum thresholds
            rules.add({
              'antecedent': itemNames[item1] ?? 'Unknown',
              'consequent': itemNames[item2] ?? 'Unknown',
              'confidence': confidence,
              'support': support,
              'lift': lift,
            });
          }
        }
      }
      
      // Sort by confidence descending
      rules.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
      
      return rules.take(5).toList();
    } catch (e) {
      print('Error calculating association rules: $e');
      return [];
    }
  }

  double _calculateConfidence(List<String> antecedent, String consequent, Map<String, List<String>> transactions) {
    int antecedentCount = 0;
    int bothCount = 0;

    for (final transaction in transactions.values) {
      final hasAntecedent = antecedent.every((item) => transaction.contains(item));
      if (hasAntecedent) {
        antecedentCount++;
        if (transaction.contains(consequent)) {
          bothCount++;
        }
      }
    }

    return antecedentCount > 0 ? bothCount / antecedentCount : 0.0;
  }

  double _calculateSupport(List<String> itemset, Map<String, List<String>> transactions) {
    int count = 0;
    for (final transaction in transactions.values) {
      if (itemset.every((item) => transaction.contains(item))) {
        count++;
      }
    }
    return transactions.isNotEmpty ? count / transactions.length : 0.0;
  }

  double _calculateLift(List<String> antecedent, String consequent, Map<String, List<String>> transactions) {
    final confidence = _calculateConfidence(antecedent, consequent, transactions);
    final consequentSupport = _calculateSupport([consequent], transactions);
    return consequentSupport > 0 ? confidence / consequentSupport : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.blue),
            SizedBox(width: 8),
            Text('🧠 AI Analytics Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('🧠 AI analyzing customer behavior patterns...'),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadAnalytics,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Global Analytics Overview
                  _buildSectionTitle('📊 Global Business Intelligence'),
                  const SizedBox(height: 16),
                  _buildGlobalAnalyticsCards(),
                  
                  const SizedBox(height: 24),
                  
                  // Association Rules (Market Basket Analysis)
                  _buildSectionTitle('🛒 Market Basket Analysis'),
                  const SizedBox(height: 8),
                  const Text(
                    'AI-discovered buying patterns: "Customers who buy X also buy Y"',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  _buildAssociationRules(),
                  
                  const SizedBox(height: 24),
                  
                  // Customer Analytics Section
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('👤 Customer Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Show customer analytics or no data message
                  _customerAnalytics != null 
                    ? _buildCustomerAnalytics()
                    : _buildNoDataMessage(),
                  
                  const SizedBox(height: 24),
                  
                  // AI Algorithm Explanation
                  _buildSectionTitle('🤖 AI Algorithms in Action'),
                  const SizedBox(height: 16),
                  _buildAlgorithmExplanation(),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
    );
  }

  Widget _buildGlobalAnalyticsCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildAnalyticsCard(
          'Total Customers',
          '${_globalAnalytics['totalCustomers'] ?? 0}',
          Icons.people,
          Colors.blue,
        ),
        _buildAnalyticsCard(
          'Total Orders',
          '${_globalAnalytics['totalOrders'] ?? 0}',
          Icons.shopping_cart,
          Colors.green,
        ),
        _buildAnalyticsCard(
          'Total Revenue',
          '₱${(_globalAnalytics['totalRevenue'] ?? 0.0).toStringAsFixed(2)}',
          Icons.monetization_on,
          Colors.orange,
        ),
        _buildAnalyticsCard(
          'Avg Order Value',
          '₱${(_globalAnalytics['averageOrderValue'] ?? 0.0).toStringAsFixed(2)}',
          Icons.trending_up,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssociationRules() {
    final rules = _globalAnalytics['associationRules'] as List<Map<String, dynamic>>? ?? [];
    
    if (rules.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Not enough data to generate association rules yet.'),
        ),
      );
    }
    
    return Card(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rules.length,
        itemBuilder: (context, index) {
          final rule = rules[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text('${index + 1}'),
            ),
            title: Text('${rule['antecedent']} → ${rule['consequent']}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Confidence: ${(rule['confidence'] * 100).toStringAsFixed(1)}%'),
                Text('Support: ${(rule['support'] * 100).toStringAsFixed(1)}%'),
                Text('Lift: ${rule['lift'].toStringAsFixed(2)}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getLiftColor(rule['lift']),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getLiftLabel(rule['lift']),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getLiftColor(double lift) {
    if (lift > 1.5) return Colors.green;
    if (lift > 1.2) return Colors.orange;
    return Colors.red;
  }

  String _getLiftLabel(double lift) {
    if (lift > 1.5) return 'Strong';
    if (lift > 1.2) return 'Moderate';
    return 'Weak';
  }

  Widget _buildCustomerAnalytics() {
    final analytics = _customerAnalytics!;
    
    return Column(
      children: [
        // Customer insights stats
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.people, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Customer Behavior Insights', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildStatsRow('Total Customer Orders', '${analytics.totalOrders}'),
                _buildStatsRow('Average Order Value (All)', '₱${analytics.averageOrderValue.toStringAsFixed(2)}'),
                _buildStatsRow('Most Recent Activity', _formatDate(analytics.lastPurchase)),
                _buildStatsRow('Total Items Sold', '${analytics.itemPurchaseFrequency.values.fold(0, (sum, count) => sum + count)}'),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Most popular items across all customers
        if (analytics.frequentItems.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.trending_up, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Most Popular Items (All Customers)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...analytics.frequentItems.take(5).map((itemId) {
                    final frequency = analytics.itemPurchaseFrequency[itemId] ?? 0;
                    return FutureBuilder<String>(
                      future: _getItemName(itemId),
                      builder: (context, snapshot) {
                        final itemName = snapshot.data ?? 'Loading...';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange[100],
                            child: Text('$frequency'),
                          ),
                          title: Text(itemName),
                          subtitle: Text('Sold $frequency time${frequency > 1 ? 's' : ''} across all customers'),
                          trailing: const Icon(Icons.local_fire_department, color: Colors.orange),
                        );
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Customer category preferences
        if (analytics.categoryPreferences.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.pie_chart, color: Colors.purple),
                      SizedBox(width: 8),
                      Text('Customer Category Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...analytics.categoryPreferences.entries.map((entry) {
                    final percentage = (entry.value * 100).toStringAsFixed(1);
                    return FutureBuilder<String>(
                      future: _getCategoryName(entry.key),
                      builder: (context, snapshot) {
                        final categoryName = snapshot.data ?? 'Loading...';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple[100],
                            child: Text('${percentage}%', style: const TextStyle(fontSize: 10)),
                          ),
                          title: Text(categoryName),
                          subtitle: Text('$percentage% of all customer purchases'),
                          trailing: SizedBox(
                            width: 100,
                            child: LinearProgressIndicator(
                              value: entry.value,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[400]!),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoDataMessage() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.people_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No customer analytics available',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Customer behavior insights will appear here once customers make purchases.\n\nCheck the console (F12) for detailed debugging information.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Analytics'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<String> _getItemName(String itemId) async {
    try {
      final doc = await _firestore.collection('items').doc(itemId).get();
      if (doc.exists) {
        return doc.data()!['name'] ?? 'Unknown Item';
      }
    } catch (e) {
      print('Error fetching item name: $e');
    }
    return 'Item #${itemId.substring(0, 8)}';
  }

  Future<String> _getCategoryName(String categoryId) async {
    try {
      final doc = await _firestore.collection('categories').doc(categoryId).get();
      if (doc.exists) {
        return doc.data()!['name'] ?? 'Unknown Category';
      }
    } catch (e) {
      print('Error fetching category name: $e');
    }
    return 'Category #${categoryId.substring(0, 8)}';
  }

  Widget _buildAlgorithmExplanation() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Recommendation Algorithms',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildAlgorithmItem(
              '🛒 Market Basket Analysis',
              'Association rule mining to find items frequently bought together',
              '35% weight',
            ),
            _buildAlgorithmItem(
              '👤 Customer Behavior Analysis',
              'Personal purchase history and category preferences',
              '25% weight',
            ),
            _buildAlgorithmItem(
              '🤝 Collaborative Filtering',
              '"Customers like you also bought" recommendations',
              '20% weight',
            ),
            _buildAlgorithmItem(
              '📈 Trend Analysis',
              'Popular items trending up in recent sales',
              '10% weight',
            ),
            _buildAlgorithmItem(
              '📂 Category Preferences',
              'Recommendations based on preferred categories',
              '10% weight',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlgorithmItem(String title, String description, String weight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(weight, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
} 