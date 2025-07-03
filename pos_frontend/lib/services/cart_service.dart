import 'package:flutter/foundation.dart';
import 'package:frontend/models/item.dart';
import 'package:frontend/models/cart_item.dart';

class CartService {
  // Using a singleton pattern to ensure a single instance of the cart
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  // Using CartItem instead of Item to handle quantities
  final ValueNotifier<List<CartItem>> _cart = ValueNotifier<List<CartItem>>([]);
  final ValueNotifier<double> _totalPrice = ValueNotifier<double>(0.0);

  ValueNotifier<List<CartItem>> get cart => _cart;
  ValueNotifier<double> get totalPrice => _totalPrice;

  // Add item to cart or increase quantity if already exists
  void addItem(Item item, {int quantity = 1}) {
    final List<CartItem> currentCart = List.from(_cart.value);
    
    // Check if item already exists in cart
    final existingIndex = currentCart.indexWhere((cartItem) => cartItem.item.id == item.id);
    
    if (existingIndex != -1) {
      // Item exists, increase quantity
      final existingCartItem = currentCart[existingIndex];
      final newQuantity = existingCartItem.quantity + quantity;
      
      // Check if we have enough stock
      if (newQuantity <= item.quantity) {
        currentCart[existingIndex] = existingCartItem.copyWith(quantity: newQuantity);
      } else {
        // Not enough stock - only add what's available
        final availableToAdd = item.quantity - existingCartItem.quantity;
        if (availableToAdd > 0) {
          currentCart[existingIndex] = existingCartItem.copyWith(quantity: item.quantity);
        }
        // Could show a snackbar here about insufficient stock
      }
    } else {
      // New item, add to cart
      // Temporarily allow adding items even if stock is 0 for testing
      if (quantity <= item.quantity || item.quantity == 0) {
        currentCart.add(CartItem(item: item, quantity: quantity));
      }
    }
    
    _cart.value = currentCart;
    _updateTotalPrice();
  }

  // Update quantity of specific item
  void updateQuantity(String itemId, int newQuantity) {
    final List<CartItem> currentCart = List.from(_cart.value);
    final index = currentCart.indexWhere((cartItem) => cartItem.item.id == itemId);
    
    if (index != -1) {
      if (newQuantity <= 0) {
        // Remove item if quantity is 0 or less
        currentCart.removeAt(index);
      } else {
        // Check stock availability
        final item = currentCart[index].item;
        final finalQuantity = newQuantity <= item.quantity ? newQuantity : item.quantity;
        currentCart[index] = currentCart[index].copyWith(quantity: finalQuantity);
      }
      
      _cart.value = currentCart;
      _updateTotalPrice();
    }
  }

  // Remove item completely from cart
  void removeItem(Item item) {
    final List<CartItem> currentCart = List.from(_cart.value);
    currentCart.removeWhere((cartItem) => cartItem.item.id == item.id);
    _cart.value = currentCart;
    _updateTotalPrice();
  }

  // Decrease quantity by 1
  void decreaseQuantity(String itemId) {
    final List<CartItem> currentCart = List.from(_cart.value);
    final index = currentCart.indexWhere((cartItem) => cartItem.item.id == itemId);
    
    if (index != -1) {
      final currentQuantity = currentCart[index].quantity;
      if (currentQuantity > 1) {
        currentCart[index] = currentCart[index].copyWith(quantity: currentQuantity - 1);
      } else {
        // Remove item if quantity becomes 0
        currentCart.removeAt(index);
      }
      
      _cart.value = currentCart;
      _updateTotalPrice();
    }
  }

  // Increase quantity by 1
  void increaseQuantity(String itemId) {
    final List<CartItem> currentCart = List.from(_cart.value);
    final index = currentCart.indexWhere((cartItem) => cartItem.item.id == itemId);
    
    if (index != -1) {
      final cartItem = currentCart[index];
      final newQuantity = cartItem.quantity + 1;
      
      // Check stock availability
      if (newQuantity <= cartItem.item.quantity) {
        currentCart[index] = cartItem.copyWith(quantity: newQuantity);
        _cart.value = currentCart;
        _updateTotalPrice();
      }
      // Could return false here to indicate insufficient stock
    }
  }

  // Clear the entire cart
  void clearCart() {
    _cart.value = [];
    _updateTotalPrice();
  }

  // Get total number of items in cart (sum of all quantities)
  int get totalItemCount {
    return _cart.value.fold(0, (sum, cartItem) => sum + cartItem.quantity);
  }

  // Update total price calculation
  void _updateTotalPrice() {
    double total = 0.0;
    for (final cartItem in _cart.value) {
      total += cartItem.totalPrice;
    }
    _totalPrice.value = total;
  }

  // Get items for checkout (convert back to Item list for compatibility)
  List<Item> getItemsForCheckout() {
    final List<Item> items = [];
    for (final cartItem in _cart.value) {
      // Add multiple entries for quantity > 1 (for compatibility with existing API)
      for (int i = 0; i < cartItem.quantity; i++) {
        items.add(cartItem.item);
      }
    }
    return items;
  }

  // Get cart items with quantities for new API
  List<CartItem> getCartItems() {
    return List.from(_cart.value);
  }
} 