import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/router/route_constants.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(AppConstants.splashDelay);
    if (!mounted) return;

    final supabase = ref.read(supabaseClientProvider);
    final session = supabase.auth.currentSession;

    if (session == null) {
      if (mounted) {
        context.go(RouteConstants.login);
      }
      return;
    }

    try {
      final repo = ref.read(authRepositoryProvider);
      final profile = await repo.getCurrentUserProfile();
      if (!mounted) return;

      if (profile?.role == UserRole.admin) {
        context.go(RouteConstants.adminDashboard);
      } else {
        context.go(RouteConstants.customerHome);
      }
    } catch (_) {
      if (mounted) {
        context.go(RouteConstants.customerHome);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(77),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.onBackgroundDark : AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.appTagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.gray400 : AppColors.gray600,
              ),
            ),
            const SizedBox(height: 48),
            const LoadingIndicator(message: 'Initializing...'),
          ],
        ),
      ),
    ),
  );
  }
}
