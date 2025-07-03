import 'package:flutter/material.dart';
import 'package:frontend/models/item.dart';
import 'package:frontend/services/ai_recommendation_service.dart';
import 'package:frontend/services/item_service.dart';
import 'package:frontend/services/cart_service.dart';
import 'dart:convert';
import 'dart:typed_data';

class RecommendationsWidget extends StatefulWidget {
  final List<Item> currentCart;

  const RecommendationsWidget({super.key, required this.currentCart});

  @override
  State<RecommendationsWidget> createState() => _RecommendationsWidgetState();
}

class _RecommendationsWidgetState extends State<RecommendationsWidget> {
  List<Item> _recommendations = [];
  bool _isLoading = false;
  String _error = '';
  final AIRecommendationService _aiService = AIRecommendationService();
  final ItemService _itemService = ItemService();
  final CartService _cartService = CartService();

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  @override
  void didUpdateWidget(RecommendationsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentCart != widget.currentCart) {
      _loadRecommendations();
    }
  }

  Future<void> _loadRecommendations() async {
    if (widget.currentCart.isEmpty) {
      setState(() {
        _recommendations = [];
        _error = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Get all available items
      final allItems = await _itemService.getItems();
      
      // Get AI-powered personalized recommendations
      final recommendations = await _aiService.getPersonalizedRecommendations(
        currentCart: widget.currentCart,
        allItems: allItems,
      );

      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load AI recommendations: $e';
        _isLoading = false;
        _recommendations = [];
      });
    }
  }

  Widget _buildRecommendationImage(Item item) {
    if (item.imageUrl == null || item.imageUrl!.isEmpty) {
      return const Icon(Icons.fastfood, size: 40, color: Colors.grey);
    }

    try {
      // Check if it's a base64 image (starts with data:)
      if (item.imageUrl!.startsWith('data:image') || item.imageUrl!.startsWith('data:application/octet-stream')) {
        final base64String = item.imageUrl!.split(',')[1];
        final Uint8List bytes = base64Decode(base64String);
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, size: 40);
            },
          ),
        );
      } else {
        // Fallback to network image
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            item.imageUrl!,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.broken_image, size: 40);
            },
          ),
        );
      }
    } catch (e) {
      return const Icon(Icons.broken_image, size: 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentCart.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.psychology, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                '🤖 AI Powered Recommendations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('🧠 AI analyzing your preferences...'),
                  ],
                ),
              ),
            )
          else if (_error.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error, style: const TextStyle(color: Colors.orange))),
                  TextButton(
                    onPressed: _loadRecommendations,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (_recommendations.isNotEmpty)
            Container(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recommendations.length,
                itemBuilder: (context, index) {
                  final item = _recommendations[index];
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          try {
                            _cartService.addItem(item, quantity: 1);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✨ ${item.name} added to cart'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to add ${item.name}: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _buildRecommendationImage(item),
                              const SizedBox(height: 8),
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                              const Spacer(),
                              Text(
                                '₱${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.grey),
                  SizedBox(width: 8),
                  Text('No recommendations available at the moment'),
                ],
              ),
            ),
        ],
      ),
    );
  }
} 