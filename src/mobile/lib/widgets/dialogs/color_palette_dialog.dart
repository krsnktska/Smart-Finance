import 'package:flutter/material.dart';
import 'package:mobile/utils/color_emoji_utils.dart';

class ColorPaletteDialog extends StatelessWidget {
  final String selectedColor;
  final void Function(String hex) onColorSelected;

  const ColorPaletteDialog({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select color'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ColorEmojiUtils.colorPalette.map((hex) {
          return GestureDetector(
            onTap: () {
              onColorSelected(hex);
              Navigator.pop(context);
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Color(
                int.parse('FF${hex.replaceAll('#', '')}', radix: 16),
              ),
              child: selectedColor.toUpperCase() == hex
                  ? const Icon(Icons.check, color: Colors.white)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
