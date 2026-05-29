import 'package:mobile/services/api_client.dart';
import 'package:mobile/config/api_config.dart';
import 'package:mobile/models/category_model.dart';

class CategoryRepository {
  final ApiClient apiClient;

  CategoryRepository({required this.apiClient});

  Future<List<CategoryModel>> getAll() async {
    final response = await apiClient.get(
      ApiConfig.categories,
      fromJson: (json) => (json as List)
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    return response;
  }

  Future<CategoryModel> getById(String categoryId) async {
    final response = await apiClient.get(
      '${ApiConfig.categories}/$categoryId',
      fromJson: (json) => CategoryModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<CategoryModel> create({
    required String name,
    required String color,
    String? emoji,
  }) async {
    final response = await apiClient.post(
      ApiConfig.categories,
      data: {
        'name': name,
        'color': color,
        if (emoji != null && emoji.isNotEmpty) 'emoji': emoji,
      },
      fromJson: (json) => CategoryModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<CategoryModel> update({
    required String categoryId,
    String? name,
    String? color,
    String? emoji,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (color != null) data['color'] = color;
    if (emoji != null) data['emoji'] = emoji;

    final response = await apiClient.put(
      '${ApiConfig.categories}/$categoryId',
      data: data,
      fromJson: (json) => CategoryModel.fromJson(json as Map<String, dynamic>),
    );
    return response;
  }

  Future<void> delete(String categoryId) async {
    await apiClient.delete('${ApiConfig.categories}/$categoryId');
  }
}
