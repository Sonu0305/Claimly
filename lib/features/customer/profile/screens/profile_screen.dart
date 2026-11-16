import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_constants.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/responsive_content_wrapper.dart';
import '../controllers/profile_controller.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  ConsumerState<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  bool _controllersInitialized = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initControllers(String? fullName, String? phone) {
    if (!_controllersInitialized) {
      _fullNameController.text = fullName ?? '';
      _phoneController.text = phone ?? '';
      _controllersInitialized = true;
    }
  }

  Future<void> _handleSave() async {
    final controller = ref.read(profileControllerProvider.notifier);
    await controller.updateProfile(
      fullName: _fullNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );
    setState(() => _isEditing = false);
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of Claimly?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(profileControllerProvider.notifier).signOut();
      if (mounted) {
        context.go(RouteConstants.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (state.isLoading && state.userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile & Settings')),
        body: const LoadingIndicator(message: 'Loading profile...'),
      );
    }

    _initControllers(state.fullName, state.phoneNumber);

    final initials = (state.fullName != null && state.fullName!.isNotEmpty)
        ? state.fullName!.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        actions: [
          IconButton(
            key: const Key('auth_logout_btn'),
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: 'Log Out',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: ResponsiveContentWrapper(
          maxWidth: 760,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // User Profile Header Card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: AppColors.primary,
                    backgroundImage: state.avatarUrl != null && state.avatarUrl!.isNotEmpty
                        ? NetworkImage(state.avatarUrl!)
                        : null,
                    child: (state.avatarUrl == null || state.avatarUrl!.isEmpty)
                        ? Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.fullName ?? 'Customer',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.email ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.gray400 : AppColors.gray600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: state.isAdmin
                          ? AppColors.claimUnderReview.withAlpha(25)
                          : AppColors.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      state.role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: state.isAdmin ? AppColors.claimUnderReview : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Statistics Summary Card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(child: _statColumn('Total Products', '${state.totalProducts}', isDark)),
                  const SizedBox(height: 36, child: VerticalDivider()),
                  Expanded(child: _statColumn('Active Warranties', '${state.activeWarranties}', isDark, color: AppColors.statusActive)),
                  const SizedBox(height: 36, child: VerticalDivider()),
                  Expanded(child: _statColumn('Total Claims', '${state.totalClaims}', isDark, color: AppColors.secondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Personal Information Card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Personal Information',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('profile_edit_btn'),
                        icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined, size: 20),
                        onPressed: () => setState(() => _isEditing = !_isEditing),
                        tooltip: _isEditing ? 'Cancel Edit' : 'Edit Profile',
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (_isEditing) ...[
                    AppTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      hint: 'Your full name',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _phoneController,
                      fieldKey: const Key('profile_phone_input'),
                      label: 'Phone Number',
                      hint: '+1 555-0199',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      buttonKey: const Key('profile_save_btn'),
                      text: 'Save Changes',
                      isLoading: state.isSaving,
                      onPressed: state.isSaving ? null : _handleSave,
                    ),
                  ] else ...[
                    _infoRow('Full Name', state.fullName ?? '—', isDark),
                    _infoRow('Email', state.email ?? '—', isDark),
                    _infoRow('Phone', state.phoneNumber ?? 'Not provided', isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Preferences & Theme Card
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferences & Theme',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                    ),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                      color: AppColors.primary,
                    ),
                    title: const Text('Theme Mode'),
                    subtitle: Text(
                      themeMode == ThemeMode.dark
                          ? 'Dark Mode'
                          : themeMode == ThemeMode.light
                              ? 'Light Mode'
                              : 'System Default',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    trailing: Switch(
                      key: const Key('theme_toggle_btn'),
                      value: isDark,
                      onChanged: (_) => themeNotifier.toggleTheme(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Admin Portal Access (if admin)
            if (state.isAdmin) ...[
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.claimUnderReview.withAlpha(20),
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(color: AppColors.claimUnderReview.withAlpha(60)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 500;
                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.admin_panel_settings, color: AppColors.claimUnderReview, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Administrator Mode',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.claimUnderReview,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Access analytics, review global claims, and manage users.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => context.go(RouteConstants.adminDashboard),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.claimUnderReview,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Open Portal'),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        const Icon(Icons.admin_panel_settings, color: AppColors.claimUnderReview, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Administrator Mode',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.claimUnderReview,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Access analytics, review global claims, and manage users.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => context.go(RouteConstants.adminDashboard),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.claimUnderReview,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Open Portal'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Logout Action Card
            AppButton(
              text: 'Log Out of Account',
              icon: const Icon(Icons.logout, size: 18),
              variant: AppButtonVariant.outlined,
              onPressed: _handleLogout,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  }

  Widget _statColumn(String label, String value, bool isDark, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color ?? (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.gray400 : AppColors.gray600,
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.gray400 : AppColors.gray600,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

