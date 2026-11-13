import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_indicator.dart';
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
      final supabase = ref.read(supabaseClientProvider);
      final response = await supabase.from('claims').select('''
        id, claim_number, user_id, product_id, type, status, title, description,
        issue_category, incident_date, priority, admin_notes, resolution_notes,
        resolved_at, created_at,
        profiles:user_id(full_name, avatar_url, phone_number),
        products:product_id(name, category, brand, model_number, serial_number, purchase_date, warranty_expiry_date),
        claim_attachments(id, file_url, file_name, file_type, file_size),
        claim_timeline(id, from_status, to_status, changed_by, notes, created_at)
      ''').eq('id', widget.claimId).single();

      if (mounted) {
        final currentStatus = response['status'] as String? ?? 'under_review';
        setState(() {
          _claimData = response;
          _selectedStatus = currentStatus == 'completed' ? 'resolved' : currentStatus;
          _priority = ((response['priority'] as num?)?.toDouble() ?? 50.0).clamp(0.0, 100.0);
          _adminNotesController.text = response['admin_notes'] as String? ?? '';
          _resolutionNotesController.text = response['resolution_notes'] as String? ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleUpdate() async {
    setState(() => _isUpdating = true);
    try {
      final controller = ref.read(adminClaimsControllerProvider.notifier);
      await controller.updateClaimStatus(
        claimId: widget.claimId,
        status: _selectedStatus,
        priority: _priority.toInt(),
        adminNotes: _adminNotesController.text.trim(),
        resolutionNotes: _resolutionNotesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim status and resolution successfully updated!'),
            backgroundColor: AppColors.success,
          ),
        );
        await _fetchClaimDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update claim: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Claim Review')),
        body: const LoadingIndicator(message: 'Loading full claim details...'),
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
              Text(_errorMessage ?? 'Claim not found'),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(claim['claim_number'] as String? ?? 'Claim Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchClaimDetail,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                      Text(
                        claim['claim_number'] as String? ?? '',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.primary,
                        ),
                      ),
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
                  const Divider(height: 16),
                  _row('Product', product?['name'] ?? '—', isDark),
                  _row('Category', product?['category'] ?? '—', isDark),
                  _row('Issue Category', claim['issue_category'] ?? '—', isDark),
                  if (claim['incident_date'] != null)
                    _row('Incident Date', claim['incident_date'] as String, isDark),
                  const SizedBox(height: 8),
                  const Text('Description:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    claim['description'] as String? ?? '',
                    style: TextStyle(fontSize: 13, color: isDark ? AppColors.gray300 : AppColors.gray800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Attachments List (if any)
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
                      'Proof Attachments (${attachments.length})',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...attachments.map((att) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.attach_file, color: AppColors.primary),
                          title: Text(att['file_name'] as String? ?? 'file', style: const TextStyle(fontSize: 13)),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Audit Timeline
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
                    Text('Transition History', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...timeline.map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              StatusBadge(status: t['to_status'] as String? ?? 'submitted', fontSize: 10),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t['notes'] as String? ?? '',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.gray400 : AppColors.gray700),
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

            // Admin Decision & Status Form
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withAlpha(70), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gavel, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Administrative Decision & Resolution',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
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
            ),
            const SizedBox(height: 24),
          ],
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
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight)),
        ],
      ),
    );
  }
}
