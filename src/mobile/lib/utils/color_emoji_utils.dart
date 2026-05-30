class ColorEmojiUtils {
  static bool isValidHexColor(String input) {
    final value = input.trim();
    final normalized = value.startsWith('#') ? value.substring(1) : value;
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized);
  }

  static String normalizeHexColor(String input) {
    var value = input.trim();
    if (!value.startsWith('#')) {
      value = '#$value';
    }
    return value.toUpperCase();
  }

  static String extractEmojis(String text) {
    final emojiRegex = RegExp(
      r'([\u{1F300}-\u{1F6FF}]|[\u{1F900}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}])',
      unicode: true,
    );
    return emojiRegex.allMatches(text).map((m) => m.group(0)).join();
  }

  static bool isEmojiOnly(String text) {
    final extracted = extractEmojis(text);
    return extracted.isNotEmpty && extracted == text;
  }

  static const List<String> colorPalette = [
    '#F44336',
    '#E91E63',
    '#9C27B0',
    '#673AB7',
    '#3F51B5',
    '#2196F3',
    '#03A9F4',
    '#00BCD4',
    '#009688',
    '#4CAF50',
    '#8BC34A',
    '#CDDC39',
    '#FFC107',
    '#FF9800',
    '#FF5722',
    '#795548',
    '#9E9E9E',
    '#607D8B',
  ];
}
