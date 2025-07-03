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
      final user = _authService.currentUser;
      
      // Load customer-specific analytics
      if (user != null) {
        final doc = await _firestore.collection('customerAnalytics').doc(user.uid).get();
        if (doc.exists) {
          _customerAnalytics = CustomerAnalytics.fromJson(doc.data()!);
        }
      }
      
      // Load global analytics
      await _loadGlobalAnalytics();
      
    } catch (e) {
      print('Error loading analytics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGlobalAnalytics() async {
    try {
      // Get all customer analytics
      final analyticsSnapshot = await _firestore.collection('customerAnalytics').get();
      
      Map<String, int> globalItemFrequency = {};
      Map<String, double> globalCategoryPreferences = {};
      List<String> allCustomers = [];
      int totalOrders = 0;
      double totalRevenue = 0.0;
      
      for (final doc in analyticsSnapshot.docs) {
        final analytics = CustomerAnalytics.fromJson(doc.data());
        allCustomers.add(analytics.customerId);
        totalOrders += analytics.totalOrders;
        totalRevenue += analytics.averageOrderValue * analytics.totalOrders;
        
        // Aggregate item frequencies
        analytics.itemPurchaseFrequency.forEach((itemId, count) {
          globalItemFrequency[itemId] = (globalItemFrequency[itemId] ?? 0) + count;
        });
        
        // Aggregate category preferences
        analytics.categoryPreferences.forEach((categoryId, preference) {
          globalCategoryPreferences[categoryId] = (globalCategoryPreferences[categoryId] ?? 0.0) + preference;
        });
      }
      
      // Calculate association rules
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
    } catch (e) {
      print('Error loading global analytics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _calculateGlobalAssociationRules() async {
    try {
      final ordersSnapshot = await _firestore.collection('orders').get();
      final orderItemsSnapshot = await _firestore.collection('orderItems').get();
      
      // Build transaction database
      Map<String, List<String>> transactions = {};
      Map<String, String> itemNames = {}; // itemId -> itemName
      
      for (final orderDoc in ordersSnapshot.docs) {
        transactions[orderDoc.id] = [];
      }
      
      for (final orderItemDoc in orderItemsSnapshot.docs) {
        final data = orderItemDoc.data();
        final orderId = data['orderId'];
        final itemId = data['itemId'];
        final itemName = data['itemName'];
        
        if (transactions.containsKey(orderId)) {
          transactions[orderId]!.add(itemId);
          itemNames[itemId] = itemName;
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
                  
                  // Customer Behavior Analysis
                  if (_customerAnalytics != null) ...[
                    _buildSectionTitle('👤 Your Personal Shopping Profile'),
                    const SizedBox(height: 16),
                    _buildCustomerAnalytics(),
                  ] else ...[
                    _buildSectionTitle('👤 Customer Analytics'),
                    const SizedBox(height: 16),
                    _buildLoginPrompt(),
                  ],
                  
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
        // Customer stats
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shopping Behavior', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Total Orders: ${analytics.totalOrders}'),
                Text('Average Order Value: ₱${analytics.averageOrderValue.toStringAsFixed(2)}'),
                Text('Last Purchase: ${analytics.lastPurchase.day}/${analytics.lastPurchase.month}/${analytics.lastPurchase.year}'),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Frequent items
        if (analytics.frequentItems.isNotEmpty) ...[
          const Text('Your Favorite Items', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: analytics.frequentItems.length,
              itemBuilder: (context, index) {
                final itemId = analytics.frequentItems[index];
                final frequency = analytics.itemPurchaseFrequency[itemId] ?? 0;
                return ListTile(
                  title: Text('Item ID: $itemId'),
                  trailing: Text('$frequency times'),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.person_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Login to see your personal shopping analytics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track your purchase patterns, favorite items, and personalized recommendations',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
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