import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:claimly/core/network/supabase_client.dart';
import 'package:claimly/core/theme/app_theme.dart';
import 'mocks.dart';

extension PumpAppTester on WidgetTester {
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
    ThemeMode themeMode = ThemeMode.light,
    ThemeData? theme,
    GoRouter? router,
    bool wrapScaffold = false,
    TextScaler? textScaler,
  }) async {
    final mockSupabase = MockSupabaseClient();
    final mockAuth = MockGoTrueClient();
    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(null);
    when(() => mockAuth.currentSession).thenReturn(null);
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => const Stream.empty());

    final defaultOverrides = <Override>[
      supabaseClientProvider.overrideWithValue(mockSupabase),
      currentUserProvider.overrideWithValue(null),
      ...overrides,
    ];

    final effectiveTheme = theme ?? AppTheme.lightTheme;
    final effectiveDarkTheme = theme ?? AppTheme.darkTheme;

    Widget buildWithScaler(BuildContext context, Widget? child) {
      if (textScaler != null) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        );
      }
      return child!;
    }

    if (router != null) {
      await pumpWidget(
        ProviderScope(
          overrides: defaultOverrides,
          child: MaterialApp.router(
            theme: effectiveTheme,
            darkTheme: effectiveDarkTheme,
            themeMode: themeMode,
            routerConfig: router,
            builder: buildWithScaler,
          ),
        ),
      );
    } else {
      await pumpWidget(
        ProviderScope(
          overrides: defaultOverrides,
          child: MaterialApp(
            theme: effectiveTheme,
            darkTheme: effectiveDarkTheme,
            themeMode: themeMode,
            home: wrapScaffold ? Scaffold(body: widget) : widget,
            builder: buildWithScaler,
          ),
        ),
      );
    }
    await pump();
  }
}
