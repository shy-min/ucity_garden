import 'package:flutter/material.dart';

/// Brand colors used throughout The Garden.
class AppColors {
  static const background = Color(0xFF25292e);
  static const surface = Color(0xFF3b3e44);
  static const green = Color(0xFF1ca931);
}

/// App-wide configuration. Change these in one place.
class AppConfig {
  static const appName = 'The Garden';
  static const churchName = 'UCity The Church';

  /// Shown in the privacy policy and Help screen. Change to a church/support
  /// address before release if you prefer not to use a personal inbox.
  static const supportEmail = 'yminor13@gmail.com';

  /// Public URL of the privacy policy (also needed in App Store Connect and the
  /// Play Console). The in-app policy screen works without it; when set, the
  /// Profile screen also offers to open the web version.
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');

  /// Stream Chat public API key (safe to ship in the app).
  static const streamApiKey = 'srzvkmn6xvrj';

  /// When true the app falls back to Stream "development tokens" if the secure
  /// token function is not deployed yet. Production builds should be made with
  /// --dart-define=STREAM_DEV_TOKENS=false once the Stream Firebase extension is
  /// installed (see STORE_RELEASE.md).
  static const allowStreamDevTokens =
      bool.fromEnvironment('STREAM_DEV_TOKENS', defaultValue: true);
}

ThemeData buildTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    primaryColor: AppColors.green,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.green,
      secondary: AppColors.green,
      surface: AppColors.background,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.green,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatDate(d);
}
