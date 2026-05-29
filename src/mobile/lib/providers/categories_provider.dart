import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:mobile/repositories/category_repository.dart';
import 'package:mobile/services/api_client.dart';
import 'package:mobile/models/category_model.dart';

final categoryRepositoryProvider = Provider((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CategoryRepository(apiClient: apiClient);
});

class CategoriesState {
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? error;

  CategoriesState({
    this.categories = const [],
    this.isLoading = false,
    this.error,
  });

  CategoriesState copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
    String? error,
  }) {
    return CategoriesState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, CategoriesState>((ref) {
      final categoryRepository = ref.watch(categoryRepositoryProvider);
      return CategoriesNotifier(categoryRepository: categoryRepository);
    });

class CategoriesNotifier extends StateNotifier<CategoriesState> {
  final CategoryRepository categoryRepository;

  CategoriesNotifier({required this.categoryRepository})
    : super(CategoriesState());

  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final categories = await categoryRepository.getAll();
      state = state.copyWith(categories: categories, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> createCategory({
    required String name,
    required String color,
    String? emoji,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final newCategory = await categoryRepository.create(
        name: name,
        color: color,
        emoji: emoji,
      );
      state = state.copyWith(
        categories: [...state.categories, newCategory],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateCategory({
    required String categoryId,
    String? name,
    String? color,
    String? emoji,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedCategory = await categoryRepository.update(
        categoryId: categoryId,
        name: name,
        color: color,
        emoji: emoji,
      );
      state = state.copyWith(
        categories: state.categories
            .map(
              (category) =>
                  category.id == categoryId ? updatedCategory : category,
            )
            .toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteCategory(String categoryId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await categoryRepository.delete(categoryId);
      state = state.copyWith(
        categories: state.categories
            .where((category) => category.id != categoryId)
            .toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}
