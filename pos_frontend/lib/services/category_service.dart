import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/category.dart';
import 'api_config.dart';

class CategoryService {
  final String _baseUrl = ApiConfig.categoriesUrl;

  Future<List<Category>> getCategories() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        List<Category> categories = body.map((dynamic item) => Category.fromJson(item)).toList();
        return categories;
      } else {
        throw "Failed to load categories";
      }
    } catch (e) {
      print('Error in getCategories: $e');
      throw e.toString();
    }
  }

  Future<Category> addCategory(Category category) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(category.toJson()),
      );
      if (response.statusCode == 201) {
        return Category.fromJson(jsonDecode(response.body));
      } else {
        throw 'Failed to add category';
      }
    } catch (e) {
      print('Error in addCategory: $e');
      throw e.toString();
    }
  }

  Future<void> updateCategory(String id, Category category) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(category.toJson()),
      );
      if (response.statusCode != 200) {
        throw 'Failed to update category';
      }
    } catch (e) {
      print('Error in updateCategory: $e');
      throw e.toString();
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/$id'));
      if (response.statusCode != 200) {
        throw 'Failed to delete category';
      }
    } catch (e) {
      print('Error in deleteCategory: $e');
      throw e.toString();
    }
  }
} 