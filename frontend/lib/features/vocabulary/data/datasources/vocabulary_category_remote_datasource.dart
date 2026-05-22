import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/error/exceptions.dart';
import '../models/vocabulary_category_model.dart';

abstract class VocabularyCategoryRemoteDataSource {
  Future<List<VocabularyCategoryModel>> getCategories(String token);
  Future<VocabularyCategoryModel> createCategory(String token, String name);
  Future<VocabularyCategoryModel> updateCategory(String token, int id, String name);
  Future<void> deleteCategory(String token, int id);
}

class VocabularyCategoryRemoteDataSourceImpl implements VocabularyCategoryRemoteDataSource {
  final http.Client client;
  final String baseUrl;

  VocabularyCategoryRemoteDataSourceImpl({required this.client, required this.baseUrl});

  @override
  Future<List<VocabularyCategoryModel>> getCategories(String token) async {
    final response = await client.get(
      Uri.parse('$baseUrl/vocabulary-categories'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => VocabularyCategoryModel.fromJson(json)).toList();
    } else {
      throw ServerException(message: 'Failed to fetch categories');
    }
  }

  @override
  Future<VocabularyCategoryModel> createCategory(String token, String name) async {
    final response = await client.post(
      Uri.parse('$baseUrl/vocabulary-categories'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 201) {
      return VocabularyCategoryModel.fromJson(jsonDecode(response.body));
    } else {
      throw ServerException(message: 'Failed to create category');
    }
  }

  @override
  Future<VocabularyCategoryModel> updateCategory(String token, int id, String name) async {
    final response = await client.put(
      Uri.parse('$baseUrl/vocabulary-categories/$id'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 200) {
      return VocabularyCategoryModel.fromJson(jsonDecode(response.body));
    } else {
      throw ServerException(message: 'Failed to update category');
    }
  }

  @override
  Future<void> deleteCategory(String token, int id) async {
    final response = await client.delete(
      Uri.parse('$baseUrl/vocabulary-categories/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw ServerException(message: body['detail'] ?? 'Failed to delete category');
    }
  }
}
