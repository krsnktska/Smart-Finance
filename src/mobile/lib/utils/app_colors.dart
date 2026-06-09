import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color expense;

  const AppColors({required this.expense});

  @override
  AppColors copyWith({Color? expense}) =>
      AppColors(expense: expense ?? this.expense);

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(expense: Color.lerp(expense, other.expense, t)!);
  }
}

extension AppColorsX on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ??
      const AppColors(expense: Color(0xFFCF3030));

  Color get expenseColor => appColors.expense;
}
