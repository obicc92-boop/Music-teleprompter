import 'package:flutter/material.dart';
import 'constants.dart';

/// One look for every screen: dialogs, menus, tooltips, messages, buttons
/// and inputs pick it up without styling each one.
ThemeData buildAppTheme() {
  const ui = AppTextStyles.ui;

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    ),
    fontFamily: ui,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      titleMedium: TextStyle(color: AppColors.textPrimary),
    ),
    hoverColor: const Color(0x0DFFFFFF),
    focusColor: const Color(0x14FFFFFF),
    splashColor: const Color(0x14FFFFFF),
    highlightColor: Colors.transparent,
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: AppColors.uiText),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: ui,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      contentTextStyle: const TextStyle(
        fontFamily: ui,
        fontSize: 14,
        height: 1.5,
        color: AppColors.uiText,
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceElevated,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      textStyle: const TextStyle(
        fontFamily: ui,
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
    ),

    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2724),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderStrong),
      ),
      textStyle: const TextStyle(
        fontFamily: ui,
        fontSize: 12,
        height: 1.4,
        color: AppColors.textPrimary,
      ),
    ),

    // The dark scheme's default snackbar text colour matches the dark
    // backgrounds used here, which made every message invisible
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 560,
      backgroundColor: const Color(0xFF26231F),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderStrong),
      ),
      contentTextStyle: const TextStyle(
        fontFamily: ui,
        fontSize: 14,
        color: AppColors.textPrimary,
      ),
      actionTextColor: AppColors.accentText,
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.uiText,
        textStyle: const TextStyle(
            fontFamily: ui, fontSize: 14, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        disabledBackgroundColor: AppColors.surfaceSelected,
        disabledForegroundColor: AppColors.uiMuted,
        elevation: 0,
        minimumSize: const Size(0, 44),
        // Desktop density would shrink it below the 44px buttons beside it
        visualDensity: VisualDensity.standard,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(
            fontFamily: ui, fontSize: 14, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.uiText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),

    // Hint colour only: a theme border would override fields that set none
    inputDecorationTheme: const InputDecorationTheme(
      hintStyle: TextStyle(fontFamily: ui, color: AppColors.uiMuted),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: Color(0x55FF6B35),
      selectionHandleColor: AppColors.accent,
    ),

    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.sliderInactive,
      thumbColor: AppColors.accent,
      overlayColor: Color(0x22FF6B35),
      trackHeight: 3,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.onAccent : AppColors.uiHint),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.accent : AppColors.surfaceSelected),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.accent : AppColors.border),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(const Color(0x33FFFFFF)),
      radius: const Radius.circular(8),
      thickness: WidgetStateProperty.all(6),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.accent),
  );
}
