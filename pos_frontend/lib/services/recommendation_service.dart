import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item.dart';

class RecommendationService {
  final String _baseUrl = 'http://localhost:3000/api/recommendations';

  Future<List<Item>> getRecommendations({
    required List<Item> currentCart,
    List<Item>? userHistory, // userHistory is optional
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'currentCart': currentCart.map((item) => item.toJson()).toList(),
          'userHistory': userHistory?.map((item) => item.toJson()).toList() ?? [],
        }),
      );

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        List<Item> items = body.map((dynamic item) => Item.fromJson(item)).toList();
        return items;
      } else {
        throw "Failed to load recommendations. Status: ${response.statusCode}, Body: ${response.body}";
      }
    } catch (e) {
      print('Error in getRecommendations: $e');
      throw e.toString();
    }
  }
} 