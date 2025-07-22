import 'package:flutter/material.dart';
import 'package:frontend/models/order.dart';
import 'package:frontend/services/order_service.dart';
import 'package:intl/intl.dart';

class AdminOrderManagementScreen extends StatefulWidget {
  const AdminOrderManagementScreen({super.key});

  @override
  State<AdminOrderManagementScreen> createState() => _AdminOrderManagementScreenState();
}

class _AdminOrderManagementScreenState extends State<AdminOrderManagementScreen> {
  List<Order> _orders = [];
  List<Order> _filteredOrders = [];
  bool _isLoading = true;
  String _selectedStatusFilter = 'all';
  String _selectedTypeFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _searchController.addListener(_filterOrders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() => _isLoading = true);
      final orders = await OrderService.getAdminOrders(limit: 100);
      setState(() {
        _orders = orders;
        _filteredOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load orders: $e')),
      );
    }
  }

  void _filterOrders() {
    setState(() {
      _filteredOrders = _orders.where((order) {
        final matchesSearch = order.customerName.toLowerCase().contains(_searchController.text.toLowerCase()) ||
            order.id.toLowerCase().contains(_searchController.text.toLowerCase());
        
        final matchesStatus = _selectedStatusFilter == 'all' || order.orderStatus.name == _selectedStatusFilter;
        final matchesType = _selectedTypeFilter == 'all' || order.orderType.name == _selectedTypeFilter;
        
        return matchesSearch && matchesStatus && matchesType;
      }).toList();
    });
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    try {
      final success = await OrderService.updateOrderStatus(
        orderId: order.id,
        orderStatus: newStatus,
      );
      
      if (success) {
        _loadOrders(); // Refresh the orders list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order status updated to ${newStatus.name}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update order status')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating order: $e')),
      );
    }
  }

  Future<void> _deleteOrder(Order order) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text(
          'Are you sure you want to delete order #${order.id.substring(0, 8)}?\n\n'
          'This action cannot be undone. The order will be permanently removed from the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await OrderService.deleteOrder(order.id);
        
        if (success) {
          _loadOrders(); // Refresh the orders list
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order #${order.id.substring(0, 8)} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete order #${order.id.substring(0, 8)}. Check console for details.'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 Order Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Filters and Search
                  _buildFiltersAndSearch(),
                  
                  // Order Statistics
                  _buildOrderStatistics(),
                  
                  // Orders List
                  _filteredOrders.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildEmptyState(),
                        )
                      : _buildOrdersList(),
                ],
              ),
            ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search orders...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(height: 12),
            
            // Filter Chips
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildFilterChip('all', 'All', _selectedStatusFilter),
                    _buildFilterChip('pending', 'Pending', _selectedStatusFilter),
                    _buildFilterChip('preparing', 'Preparing', _selectedStatusFilter),
                    _buildFilterChip('ready', 'Ready', _selectedStatusFilter),
                    _buildFilterChip('completed', 'Completed', _selectedStatusFilter),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildFilterChip('all', 'All', _selectedTypeFilter),
                    _buildFilterChip('pickup', 'Pickup', _selectedTypeFilter),
                    _buildFilterChip('delivery', 'Delivery', _selectedTypeFilter),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, String selectedValue) {
    final isSelected = selectedValue == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selectedValue == _selectedStatusFilter) {
            _selectedStatusFilter = value;
          } else {
            _selectedTypeFilter = value;
          }
        });
        _filterOrders();
      },
    );
  }

  Widget _buildOrderStatistics() {
    final pendingCount = _orders.where((o) => o.orderStatus == OrderStatus.pending).length;
    final preparingCount = _orders.where((o) => o.orderStatus == OrderStatus.preparing).length;
    final readyCount = _orders.where((o) => o.orderStatus == OrderStatus.ready).length;
    final completedToday = _orders.where((o) => 
      o.orderStatus == OrderStatus.completed && 
      o.createdAt.isAfter(DateTime.now().subtract(const Duration(days: 1)))
    ).length;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 16,
          runSpacing: 12,
          children: [
            _buildStatItem('📥 Pending', pendingCount, Colors.orange),
            _buildStatItem('👨‍🍳 Preparing', preparingCount, Colors.blue),
            _buildStatItem('✅ Ready', readyCount, Colors.green),
            _buildStatItem('🎉 Today', completedToday, Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Orders will appear here when customers place them',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: _filteredOrders.map((order) => _buildOrderCard(order)).toList(),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(order.orderStatus),
          child: Text(
            order.id.substring(0, 2).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          '${order.customerName} - ₱${order.totalPrice.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.orderStatus),
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
                const SizedBox(width: 8),
                Icon(
                  order.orderType == OrderType.pickup ? Icons.store : Icons.local_shipping,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.orderType == OrderType.pickup ? 'Pickup' : 'Delivery',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Order #${order.id.substring(0, 8)} • ${DateFormat('MMM dd, HH:mm').format(order.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        children: [
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Information
                    _buildOrderSection('Customer Information', [
                      _buildInfoRow('Name', order.customerName),
                      _buildInfoRow('Email', order.customerEmail),
                      if (order.customerPhone != null)
                        _buildInfoRow('Phone', order.customerPhone!),
                    ]),
                    
                    // Order Items
                    _buildOrderSection('Order Items', [
                      ...order.items.map((item) => _buildItemRow(item)),
                    ]),
                    
                    // Order Details
                    _buildOrderSection('Order Details', [
                      _buildInfoRow('Order Type', order.orderType.name.toUpperCase()),
                      _buildInfoRow('Payment Method', order.paymentMethod.name.toUpperCase()),
                      _buildInfoRow('Payment Status', order.paymentStatus.name.toUpperCase()),
                      _buildInfoRow('Total Amount', '₱${order.totalPrice.toStringAsFixed(2)}'),
                      if (order.deliveryAddress != null) ...[
                        _buildDeliveryAddressSection(order.deliveryAddress!),
                      ],
                      // Always show delivery instructions section for delivery orders
                      if (order.orderType == OrderType.delivery) ...[
                        _buildDeliveryInstructionsSection(
                          order.deliveryInstructions ?? 'No special delivery instructions provided'
                        ),
                      ],
                    ]),
                    
                    // Order Actions
                    const SizedBox(height: 8),
                    _buildOrderActions(order),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressSection(DeliveryAddress address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Address:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                address.street,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              Text(
                '${address.city}, ${address.province}',
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
              Text(
                'Postal Code: ${address.postalCode}',
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),
              Text(
                'Contact: ${address.contactNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (address.landmarks != null && address.landmarks!.isNotEmpty)
                Text(
                  'Landmarks: ${address.landmarks}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryInstructionsSection(String instructions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Instructions:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.notes,
                size: 16,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  instructions,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
    Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '${item.quantity}x',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.itemName,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '₱${(item.price * item.quantity).toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActions(Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Actions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (order.orderStatus == OrderStatus.pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ElevatedButton.icon(
                  onPressed: () => _updateOrderStatus(order, OrderStatus.preparing),
                  icon: const Icon(Icons.restaurant, size: 16),
                  label: const Text('Start Preparing', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            if (order.orderStatus == OrderStatus.preparing)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ElevatedButton.icon(
                  onPressed: () => _updateOrderStatus(order, OrderStatus.ready),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: Text(
                    order.orderType == OrderType.pickup ? 'Ready for Pickup' : 'Ready for Delivery',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            if (order.orderStatus == OrderStatus.ready)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ElevatedButton.icon(
                  onPressed: () => _updateOrderStatus(order, OrderStatus.completed),
                  icon: const Icon(Icons.done_all, size: 16),
                  label: Text(
                    order.orderType == OrderType.pickup ? 'Picked Up' : 'Delivered',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            if (order.orderStatus != OrderStatus.completed && order.orderStatus != OrderStatus.cancelled)
              OutlinedButton.icon(
                onPressed: () => _updateOrderStatus(order, OrderStatus.cancelled),
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('Cancel Order', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            if (order.orderStatus == OrderStatus.completed || order.orderStatus == OrderStatus.cancelled)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: OutlinedButton.icon(
                  onPressed: () => _deleteOrder(order),
                  icon: const Icon(Icons.delete_forever, size: 16),
                  label: const Text('Delete Order', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
          ],
        ),
      ],
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
} 