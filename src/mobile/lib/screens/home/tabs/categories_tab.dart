import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/providers/categories_provider.dart';
import 'package:mobile/models/category_model.dart';
import 'package:mobile/utils/color_emoji_utils.dart';
import 'package:mobile/widgets/dialogs/color_palette_dialog.dart';

class CategoriesTab extends ConsumerWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesState = ref.watch(categoriesProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(categoriesProvider.notifier).loadCategories(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Categories', style: Theme.of(context).textTheme.titleLarge),
              ElevatedButton.icon(
                onPressed: () => _showCreateCategoryDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (categoriesState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (categoriesState.error != null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${categoriesState.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(categoriesProvider.notifier).loadCategories();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else if (categoriesState.categories.isEmpty)
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text('No categories yet'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateCategoryDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create First Category'),
                  ),
                ],
              ),
            )
          else
            ...categoriesState.categories.map((category) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: category.categoryColor,
                    child: Text(
                      category.emoji ??
                          category.name.characters.first.toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(category.name),
                  subtitle: Text(category.color),
                  trailing: PopupMenuButton<String>(
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditCategoryDialog(context, ref, category);
                      } else if (value == 'delete') {
                        _showDeleteCategoryDialog(
                          context,
                          ref,
                          category.id,
                          category.name,
                        );
                      }
                    },
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  void _showCreateCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final colorController = TextEditingController(text: '#2196F3');
    final emojiController = TextEditingController();
    var selectedColor = '#2196F3';
    String? colorError;
    String? emojiError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: InputDecoration(
                  hintText: 'Color (#RRGGBB)',
                  errorText: colorError,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.color_lens),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => ColorPaletteDialog(
                          selectedColor: selectedColor,
                          onColorSelected: (hex) {
                            setState(() {
                              selectedColor = hex;
                              colorController.text = hex;
                              colorError = null;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emojiController,
                decoration: InputDecoration(
                  hintText: 'Emoji (optional)',
                  errorText: emojiError,
                ),
                onChanged: (value) {
                  final filtered = ColorEmojiUtils.extractEmojis(value);
                  if (filtered != value) {
                    emojiController.value = emojiController.value.copyWith(
                      text: filtered,
                      selection: TextSelection.collapsed(
                        offset: filtered.length,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final color = ColorEmojiUtils.normalizeHexColor(
                  colorController.text.trim(),
                );
                final emoji = emojiController.text.trim();
                if (name.isEmpty || color.isEmpty) return;
                if (!ColorEmojiUtils.isValidHexColor(color)) {
                  setState(() {
                    colorError = 'Enter a valid #RRGGBB color';
                  });
                  return;
                }
                if (emoji.isNotEmpty && !ColorEmojiUtils.isEmojiOnly(emoji)) {
                  setState(() {
                    emojiError = 'Only emoji characters allowed';
                  });
                  return;
                }
                final success = await ref
                    .read(categoriesProvider.notifier)
                    .createCategory(
                      name: name,
                      color: color,
                      emoji: emoji.isEmpty ? null : emoji,
                    );
                if (!context.mounted) return;
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category created'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  final error = ref.read(categoriesProvider).error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'Could not create category'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    CategoryModel category,
  ) {
    final nameController = TextEditingController(text: category.name);
    final colorController = TextEditingController(text: category.color);
    final emojiController = TextEditingController(text: category.emoji ?? '');
    var selectedColor = category.color;
    String? colorError;
    String? emojiError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                decoration: InputDecoration(
                  hintText: 'Color (#RRGGBB)',
                  errorText: colorError,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.color_lens),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => ColorPaletteDialog(
                          selectedColor: selectedColor,
                          onColorSelected: (hex) {
                            setState(() {
                              selectedColor = hex;
                              colorController.text = hex;
                              colorError = null;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emojiController,
                decoration: InputDecoration(
                  hintText: 'Emoji (optional)',
                  errorText: emojiError,
                ),
                onChanged: (value) {
                  final filtered = ColorEmojiUtils.extractEmojis(value);
                  if (filtered != value) {
                    emojiController.value = emojiController.value.copyWith(
                      text: filtered,
                      selection: TextSelection.collapsed(
                        offset: filtered.length,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final color = ColorEmojiUtils.normalizeHexColor(
                  colorController.text.trim(),
                );
                final emoji = emojiController.text.trim();
                if (name.isEmpty || color.isEmpty) return;
                if (!ColorEmojiUtils.isValidHexColor(color)) {
                  setState(() {
                    colorError = 'Enter a valid #RRGGBB color';
                  });
                  return;
                }
                if (emoji.isNotEmpty && !ColorEmojiUtils.isEmojiOnly(emoji)) {
                  setState(() {
                    emojiError = 'Only emoji characters allowed';
                  });
                  return;
                }
                final success = await ref
                    .read(categoriesProvider.notifier)
                    .updateCategory(
                      categoryId: category.id,
                      name: name,
                      color: color,
                      emoji: emoji.isEmpty ? null : emoji,
                    );
                if (!context.mounted) return;
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Category updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  final error = ref.read(categoriesProvider).error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'Could not update category'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    String categoryId,
    String categoryName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$categoryName"?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final success = await ref
                  .read(categoriesProvider.notifier)
                  .deleteCategory(categoryId);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Category deleted'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                final error = ref.read(categoriesProvider).error;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Could not delete category'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
