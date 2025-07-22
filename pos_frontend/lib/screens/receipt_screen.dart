import 'package:flutter/material.dart';
import 'package:frontend/models/order.dart';
import 'package:intl/intl.dart';

class ReceiptScreen extends StatelessWidget {
  final Order order;

  const ReceiptScreen({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Receipt',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFF8C00),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSuccessMessage(),
            const SizedBox(height: 24),
            _buildReceiptCard(),
            const SizedBox(height: 24),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 64,
          ),
          const SizedBox(height: 12),
          const Text(
            'Order Placed Successfully!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.orderType == OrderType.pickup
                ? 'Your order will be ready for pickup soon.'
                : 'Your order will be delivered to your address.',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'GENSUGGEST POS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Order Details
            _buildOrderDetails(),
            const Divider(height: 32),

            // Customer Information
            _buildCustomerInfo(),
            const Divider(height: 32),

            // Order Items
            _buildOrderItems(),
            const Divider(height: 32),

            // Payment Summary
            _buildPaymentSummary(),

            // Order Status
            if (order.orderStatus != OrderStatus.pending) ...[
              const Divider(height: 32),
              _buildOrderStatus(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF8C00),
          ),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Order ID', order.id.substring(0, 8).toUpperCase()),
        _buildDetailRow('Date', DateFormat('MMM dd, yyyy HH:mm').format(order.createdAt)),
        _buildDetailRow('Order Type', _getOrderTypeDisplay()),
        _buildDetailRow('Payment Method', _getPaymentMethodDisplay()),
        _buildDetailRow('Status', order.statusDisplayText),
        if (order.estimatedReadyTime != null)
          _buildDetailRow(
            order.orderType == OrderType.pickup ? 'Ready Time' : 'Delivery Time',
            DateFormat('MMM dd, yyyy HH:mm').format(order.estimatedReadyTime!),
          ),
      ],
    );
  }

  Widget _buildCustomerInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF8C00),
          ),
        ),
        const SizedBox(height: 12),
        _buildDetailRow('Name', order.customerName),
        _buildDetailRow('Email', order.customerEmail),
        if (order.customerPhone != null)
          _buildDetailRow('Phone', order.customerPhone!),
        
        // Delivery Address (if applicable)
        if (order.deliveryAddress != null) ...[
          const SizedBox(height: 12),
          const Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.deliveryAddress!.street),
                Text('${order.deliveryAddress!.city}, ${order.deliveryAddress!.province}'),
                Text(order.deliveryAddress!.postalCode),
                if (order.deliveryAddress!.landmarks != null)
                  Text('Landmarks: ${order.deliveryAddress!.landmarks}'),
                Text('Contact: ${order.deliveryAddress!.contactNumber}'),
              ],
            ),
          ),
        ],
        
        // Delivery Instructions (if applicable)
        if (order.orderType == OrderType.delivery) ...[
          const SizedBox(height: 12),
          const Text(
            'Delivery Instructions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes, size: 16, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.deliveryInstructions ?? 'No special delivery instructions provided',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrderItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Items',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF8C00),
          ),
        ),
        const SizedBox(height: 12),
        ...order.items.map((item) => _buildItemRow(item)),
      ],
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.itemName,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'x${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₱${(item.price * item.quantity).toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Summary',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF8C00),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Items:',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              '${order.totalItemCount}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Amount:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '₱${order.totalPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF8C00),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Payment Status: '),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPaymentStatusColor(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getPaymentStatusText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (order.paymentTransactionId != null) ...[
          const SizedBox(height: 8),
          _buildDetailRow('Transaction ID', order.paymentTransactionId!),
        ],
      ],
    );
  }

  Widget _buildOrderStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF8C00),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getStatusColor(),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _getStatusIcon(),
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  order.statusDisplayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (order.adminNotes != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Notes:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(order.adminNotes!),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.home),
            label: const Text('Back to Home', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement share receipt functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share receipt feature coming soon!')),
              );
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF8C00)),
              foregroundColor: const Color(0xFFFF8C00),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.share),
            label: const Text('Share Receipt', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  String _getOrderTypeDisplay() {
    switch (order.orderType) {
      case OrderType.pickup:
        return 'Store Pickup';
      case OrderType.delivery:
        return 'Home Delivery';
    }
  }

  String _getPaymentMethodDisplay() {
    switch (order.paymentMethod) {
      case PaymentMethod.cash:
        return order.orderType == OrderType.pickup ? 'Cash on Pickup' : 'Cash on Delivery';
      case PaymentMethod.gcash:
        return 'GCash';
    }
  }

  String _getPaymentStatusText() {
    switch (order.paymentStatus) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  Color _getPaymentStatusColor() {
    switch (order.paymentStatus) {
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.failed:
        return Colors.red;
      case PaymentStatus.refunded:
        return Colors.blue;
    }
  }

  Color _getStatusColor() {
    switch (order.orderStatus) {
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

  IconData _getStatusIcon() {
    switch (order.orderStatus) {
      case OrderStatus.pending:
        return Icons.access_time;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return order.orderType == OrderType.pickup ? Icons.store : Icons.local_shipping;
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }
} 