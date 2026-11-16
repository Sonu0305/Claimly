import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/responsive_content_wrapper.dart';
import '../../../../core/widgets/status_badge.dart';
import '../controllers/admin_claims_controller.dart';

class AdminClaimDetailScreen extends ConsumerStatefulWidget {
  final String claimId;

  const AdminClaimDetailScreen({
    super.key,
    required this.claimId,
  });

  @override
  ConsumerState<AdminClaimDetailScreen> createState() => _AdminClaimDetailScreenState();
}

class _AdminClaimDetailScreenState extends ConsumerState<AdminClaimDetailScreen> {
  Map<String, dynamic>? _claimData;
  bool _isLoading = true;
  bool _isUpdating = false;
  String? _errorMessage;

  String _selectedStatus = 'under_review';
  double _priority = 50;
  final _adminNotesController = TextEditingController();
  final _resolutionNotesController = TextEditingController();

  static const List<Map<String, String>> _statusOptions = [
    {'label': 'Under Review', 'value': 'under_review'},
    {'label': 'Approve Claim', 'value': 'approved'},
    {'label': 'Reject Claim', 'value': 'rejected'},
    {'label': 'Mark as Resolved', 'value': 'resolved'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchClaimDetail();
  }

  @override
  void dispose() {
    _adminNotesController.dispose();
    _resolutionNotesController.dispose();
    super.dispose();
  }

  Future<void> _fetchClaimDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final res = await client
          .from('claims')
          .select('''
            *,
            profiles!claims_user_id_fkey(id, full_name, email, phone_number),
            products!claims_product_id_fkey(id, name, brand, model_number, serial_number, warranty_expiry_date),
            claim_attachments(*),
            claim_timeline(*)
          ''')
          .eq('id', widget.claimId)
          .single();

      if (!mounted) return;

      setState(() {
        _claimData = res;
        _selectedStatus = res['status'] as String? ?? 'under_review';
        _priority = (res['priority'] as num?)?.toDouble() ?? 50.0;
        _adminNotesController.text = res['admin_notes'] as String? ?? '';
        _resolutionNotesController.text = res['resolution_notes'] as String? ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUpdate() async {
    setState(() => _isUpdating = true);

    try {
      final client = ref.read(supabaseClientProvider);
      final currentUserId = client.auth.currentUser?.id;

      await client.from('claims').update({
        'status': _selectedStatus,
        'priority': _priority.toInt(),
        'admin_notes': _adminNotesController.text.trim().isEmpty ? null : _adminNotesController.text.trim(),
        'resolution_notes': _resolutionNotesController.text.trim().isEmpty ? null : _resolutionNotesController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.claimId);

      // Audit log entry
      if (currentUserId != null) {
        await client.from('claim_timeline').insert({
          'claim_id': widget.claimId,
          'status': _selectedStatus,
          'title': 'Status Updated by Administrator',
          'description': 'Claim status set to $_selectedStatus. Priority: ${_priority.toInt()}. Notes: ${_resolutionNotesController.text.trim()}',
          'created_by': currentUserId,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;

      // Invalidate admin controller to update lists
      ref.invalidate(adminClaimsControllerProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim decision recorded and status updated successfully')),
      );

      await _fetchClaimDetail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update claim: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final isDualPane = width >= 900;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Claim Review')),
        body: const LoadingIndicator(message: 'Loading claim review data...'),
      );
    }

    if (_errorMessage != null || _claimData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Claim Review')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Claim not found', style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchClaimDetail, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final claim = _claimData!;
    final profile = claim['profiles'] as Map<String, dynamic>?;
    final product = claim['products'] as Map<String, dynamic>?;
    final attachments = claim['claim_attachments'] as List<dynamic>? ?? [];
    final timeline = claim['claim_timeline'] as List<dynamic>? ?? [];

    final leftOverview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Info Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      claim['claim_number'] as String? ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: claim['status'] as String? ?? 'submitted'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                claim['title'] as String? ?? '',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Customer: ${profile?['full_name'] ?? 'Unknown'} • Type: ${(claim['type'] as String? ?? '').toUpperCase()}',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Product & Issue Details
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product & Failure Details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                ),
              ),
              const Divider(height: 20),
              _row('Product Name', product?['name'] as String? ?? 'Unspecified', isDark),
              _row('Brand', product?['brand'] as String? ?? '—', isDark),
              _row('Model Number', product?['model_number'] as String? ?? '—', isDark),
              _row('Serial Number', product?['serial_number'] as String? ?? '—', isDark),
              _row('Issue Category', claim['issue_category'] as String? ?? 'General', isDark),
              const SizedBox(height: 8),
              const Text('Reported Failure Description:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                claim['description'] as String? ?? '',
                style: TextStyle(fontSize: 13, height: 1.4, color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Attachments
        if (attachments.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proof Documents (${attachments.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 8),
                ...attachments.map((att) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          att['file_name'] as String? ?? 'Document',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Transition Audit History
        if (timeline.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transition Audit History',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                  ),
                ),
                const SizedBox(height: 12),
                ...timeline.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.history, size: 16, color: AppColors.gray400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            if (t['description'] != null)
                              Text(t['description'] as String, style: TextStyle(fontSize: 11, color: isDark ? AppColors.gray400 : AppColors.gray600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );

    final decisionPanel = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Administrative Decision & Resolution',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),

          // Status Dropdown
          const Text('Set Claim Status *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: const Key('admin_claim_status_dropdown'),
            initialValue: _selectedStatus,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: _statusOptions
                .map((opt) => DropdownMenuItem(value: opt['value'], child: Text(opt['label']!)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedStatus = val);
            },
          ),
          const SizedBox(height: 16),

          // Priority Override
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Priority Score (0 - 100):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text('${_priority.toInt()} / 100', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          Slider(
            key: const Key('admin_priority_override_input'),
            value: _priority,
            min: 0,
            max: 100,
            divisions: 100,
            label: _priority.toInt().toString(),
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _priority = val),
          ),
          const SizedBox(height: 12),

          // Internal Admin Notes
          AppTextField(
            controller: _adminNotesController,
            fieldKey: const Key('admin_notes_input'),
            label: 'Internal Admin Notes',
            hint: 'Private notes for admin logs and audit history...',
            maxLines: 2,
          ),
          const SizedBox(height: 14),

          // User-Facing Resolution Notes
          AppTextField(
            controller: _resolutionNotesController,
            fieldKey: const Key('admin_resolution_input'),
            label: 'Resolution Explanation (Sent to Customer)',
            hint: 'Explain reason for approval, rejection, or required repair steps...',
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Submit Update Button
          AppButton(
            buttonKey: const Key('admin_update_status_btn'),
            text: 'Submit Decision & Notify User',
            icon: const Icon(Icons.check_circle_outline),
            isLoading: _isUpdating,
            onPressed: _isUpdating ? null : _handleUpdate,
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(claim['claim_number'] as String? ?? 'Claim Review', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchClaimDetail,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: ResponsiveContentWrapper(
          maxWidth: AppBreakpoints.maxContentWidth,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: isDualPane
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: leftOverview),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: decisionPanel),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftOverview,
                    decisionPanel,
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? AppColors.gray400 : AppColors.gray600)),
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
