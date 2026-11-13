import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:claimly/core/constants/app_constants.dart';
import 'package:claimly/core/theme/theme_provider.dart';

void main() {
  group('ThemeModeNotifier', () {
    test('defaults to ThemeMode.system when no preference is saved', () {
      final notifier = ThemeModeNotifier(null);
      expect(notifier.state, ThemeMode.system);
    });

    test('initializes with saved preference', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.themeModeKey: 'dark',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeModeNotifier(prefs);

      expect(notifier.state, ThemeMode.dark);
    });

    test('setThemeMode updates state and persists to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeModeNotifier(prefs);

      await notifier.setThemeMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);
      expect(prefs.getString(AppConstants.themeModeKey), 'light');

      await notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.state, ThemeMode.dark);
      expect(prefs.getString(AppConstants.themeModeKey), 'dark');
    });

    test('toggleTheme alternates between dark and light', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.themeModeKey: 'light',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = ThemeModeNotifier(prefs);

      await notifier.toggleTheme();
      expect(notifier.state, ThemeMode.dark);

      await notifier.toggleTheme();
      expect(notifier.state, ThemeMode.light);
    });

    test('themeModeProvider integrates with ProviderContainer', () async {
      SharedPreferences.setMockInitialValues({
        AppConstants.themeModeKey: 'dark',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);

      await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);
    });
  });
}
