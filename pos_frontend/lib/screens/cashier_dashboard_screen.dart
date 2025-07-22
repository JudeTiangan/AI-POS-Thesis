import 'package:flutter/material.dart';
import 'package:frontend/screens/reports_screen.dart';
import 'package:frontend/screens/admin_order_management_screen.dart';
import 'package:frontend/screens/cashier_pos_screen.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/services/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CashierDashboardScreen extends StatefulWidget {
  const CashierDashboardScreen({super.key});

  @override
  State<CashierDashboardScreen> createState() => _CashierDashboardScreenState();
}

class _CashierDashboardScreenState extends State<CashierDashboardScreen> {
  final AuthService authService = AuthService();
  bool _isLoading = true;
  int _todayOrders = 0;
  double _todaySales = 0.0;
  int _pendingOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayAnalytics();
  }

  Future<void> _loadTodayAnalytics() async {
    try {
      setState(() => _isLoading = true);
      
      // Use the efficient backend analytics endpoint
      final response = await http.get(
        Uri.parse('${ApiConfig.analyticsUrl}/today'),
        headers: {'Content-Type': 'application/json'},
      );
      
      print('📊 Analytics API response: ${response.statusCode}');
      print('📊 Analytics API body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        setState(() {
          _todayOrders = data['todayOrders'] ?? 0;
          _todaySales = (data['todaySales'] ?? 0.0).toDouble();
          _pendingOrders = data['pendingOrders'] ?? 0;
          _isLoading = false;
        });
        
        print('✅ Today\'s Analytics loaded: Orders: $_todayOrders, Sales: ₱$_todaySales, Pending: $_pendingOrders');
        
      } else {
        throw Exception('Analytics API returned ${response.statusCode}: ${response.body}');
      }
      
    } catch (e) {
      print('❌ Error loading today\'s analytics: $e');
      setState(() => _isLoading = false);
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load analytics: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💼 Cashier Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodayAnalytics,
            tooltip: 'Refresh Analytics',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              // AuthWrapper will handle navigation
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to Cashier Station',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Process orders, view reports, and manage order status',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              
              // Quick Actions Section
              const Text(
                '⚡ Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 16),
              
              // Main POS Action (Prominent)
              Container(
                width: double.infinity,
                height: 120,
                margin: const EdgeInsets.only(bottom: 16),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.teal[50],
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CashierPOSScreen()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.teal,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.point_of_sale,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '🛒 Process Orders',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Quick checkout for walk-in customers',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.teal,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Secondary Actions Row
              Row(
                children: [
                  Expanded(
                    child: _buildDashboardCard(
                      context,
                      'Order Status',
                      'View and update order status',
                      Icons.receipt_long,
                      Colors.blue,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const AdminOrderManagementScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDashboardCard(
                      context,
                      'Sales Reports',
                      'View daily sales and statistics',
                      Icons.bar_chart,
                      Colors.orange,
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ReportsScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Current Status Section
              const Text(
                '📊 Today\'s Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
              ),
              const SizedBox(height: 16),
              
              _buildStatusCard(),
              
              const SizedBox(height: 24),
              
              // Cashier Features
              _buildCashierFeaturesCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick Stats',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadTodayAnalytics,
                    tooltip: 'Refresh analytics',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  'Orders', 
                  _isLoading ? '...' : _todayOrders.toString(), 
                  Colors.blue
                ),
                _buildStatItem(
                  'Sales', 
                  _isLoading ? '...' : '₱${_todaySales.toStringAsFixed(2)}', 
                  Colors.green
                ),
                _buildStatItem(
                  'Pending', 
                  _isLoading ? '...' : _pendingOrders.toString(), 
                  Colors.orange
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCashierFeaturesCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.verified_user, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  '👨‍💼 Cashier Features',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFeatureItem('✅ Quick Checkout', 'Process walk-in customer orders'),
            _buildFeatureItem('📋 Order Management', 'Update order status and track progress'),
            _buildFeatureItem('📊 Sales Reporting', 'View daily sales and performance metrics'),
            _buildFeatureItem('💳 Payment Processing', 'Handle cash and digital payments'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 