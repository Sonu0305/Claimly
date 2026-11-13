import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimly/core/constants/app_colors.dart';
import 'package:claimly/core/widgets/app_text_field.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import '../controllers/wizard_controller.dart';

class StepIssueDetails extends ConsumerStatefulWidget {
  final ProductModel? initialProduct;

  const StepIssueDetails({
    super.key,
    this.initialProduct,
  });

  @override
  ConsumerState<StepIssueDetails> createState() => _StepIssueDetailsState();
}

class _StepIssueDetailsState extends ConsumerState<StepIssueDetails> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _dateController;
  String _category = 'Hardware Defect';
  DateTime _incidentDate = DateTime.now();

  static const List<String> _issueCategories = [
    'Hardware Defect',
    'Software Glitch',
    'Physical Damage',
    'Missing Parts',
    'Battery & Power',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final state = ref.read(claimWizardControllerProvider(widget.initialProduct));
    _titleController = TextEditingController(text: state.issueTitle);
    _descriptionController = TextEditingController(text: state.issueDescription);
    _category = state.issueCategory ?? 'Hardware Defect';
    _incidentDate = state.incidentDate ?? DateTime.now();
    _dateController = TextEditingController(
      text: _incidentDate.toIso8601String().split('T')[0],
    );

    _syncState();
  }

  void _syncState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(claimWizardControllerProvider(widget.initialProduct).notifier).setIssueDetails(
            title: _titleController.text,
            description: _descriptionController.text,
            category: _category,
            incidentDate: _incidentDate,
          );
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _incidentDate = picked;
        _dateController.text = picked.toIso8601String().split('T')[0];
      });
      _syncState();
    }
  }

  String? _validateIncidentDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Incident date is required';
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return 'Invalid date format';

    if (parsed.isAfter(DateTime.now())) {
      return 'Incident date cannot be in the future';
    }

    final state = ref.read(claimWizardControllerProvider(widget.initialProduct));
    final product = state.selectedProduct;
    if (product != null && parsed.isBefore(product.purchaseDate)) {
      return 'Incident date cannot precede product purchase date';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Issue Details & Failure Description',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Describe the exact symptom, malfunction, or safety concern:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.gray400 : AppColors.gray600,
            ),
          ),
          const SizedBox(height: 20),

          // Issue Title
          AppTextField(
            controller: _titleController,
            fieldKey: const Key('wizard_issue_title_input'),
            label: 'Issue Title *',
            hint: 'e.g. Screen flickering under load, Battery overheating',
            onChanged: (_) => _syncState(),
            validator: (v) {
              if (v == null || v.trim().length < 5) {
                return 'Title must be at least 5 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Issue Category
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Issue Category *',
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray700,
                ),
              ),
              const SizedBox(height: 6.0),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: _issueCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _category = val);
                    _syncState();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Incident Date
          GestureDetector(
            onTap: () => _pickDate(context),
            child: AbsorbPointer(
              child: AppTextField(
                controller: _dateController,
                fieldKey: const Key('wizard_incident_date_input'),
                label: 'Incident Date *',
                hint: 'YYYY-MM-DD',
                prefixIcon: const Icon(Icons.calendar_today, size: 18),
                validator: _validateIncidentDate,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Issue Description
          AppTextField(
            controller: _descriptionController,
            fieldKey: const Key('wizard_issue_desc_input'),
            label: 'Detailed Description *',
            hint: 'Explain what happened, frequency of occurrence, and troubleshooting attempted...',
            maxLines: 4,
            onChanged: (_) => _syncState(),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please provide a detailed description';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Helpful tip
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoLight.withAlpha(50),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.info.withAlpha(50)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AppColors.info, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Safety concerns (e.g. fire, smoke, electrical shock, burn) are automatically flagged for expedited priority triage.',
                    style: TextStyle(fontSize: 12, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
