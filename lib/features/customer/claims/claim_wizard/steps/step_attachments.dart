import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:claimly/core/constants/app_colors.dart';
import 'package:claimly/features/customer/products/models/product_model.dart';
import '../controllers/wizard_controller.dart';
import '../models/wizard_state.dart';

class StepAttachments extends ConsumerStatefulWidget {
  final ProductModel? initialProduct;

  const StepAttachments({
    super.key,
    this.initialProduct,
  });

  @override
  ConsumerState<StepAttachments> createState() => _StepAttachmentsState();
}

class _StepAttachmentsState extends ConsumerState<StepAttachments> {
  static const int maxFileSizeBytes = 20 * 1024 * 1024; // 20 MB
  static const List<String> allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
    'mp4',
  ];

  void _showAddAttachmentDialog() {
    final nameController = TextEditingController(text: 'receipt_proof.jpg');
    final sizeController = TextEditingController(text: '1024');
    String? dialogError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Proof Attachment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dialogError != null) ...[
                  Text(
                    dialogError!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'File Name with extension',
                    hintText: 'e.g. proof_photo.jpg, receipt.pdf',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'File Size (bytes)',
                    hintText: '1024',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final fileName = nameController.text.trim();
                  final ext = fileName.contains('.')
                      ? fileName.split('.').last.toLowerCase()
                      : '';
                  final size = int.tryParse(sizeController.text.trim()) ?? 1024;

                  if (!allowedExtensions.contains(ext)) {
                    setDialogState(() {
                      dialogError =
                          'Unsupported file format. Please upload JPG, PNG, PDF, or MP4.';
                    });
                    return;
                  }

                  if (size > maxFileSizeBytes) {
                    setDialogState(() {
                      dialogError = 'File size exceeds maximum 20MB limit';
                    });
                    return;
                  }

                  String mimeType = 'application/octet-stream';
                  if (ext == 'pdf') {
                    mimeType = 'application/pdf';
                  } else if (ext == 'mp4') {
                    mimeType = 'video/mp4';
                  } else {
                    mimeType = 'image/$ext';
                  }

                  final item = WizardAttachmentItem(
                    fileName: fileName,
                    bytes: Uint8List(size > 1024 ? 1024 : size),
                    size: size,
                    mimeType: mimeType,
                  );

                  ref
                      .read(claimWizardControllerProvider(widget.initialProduct).notifier)
                      .addAttachment(item);

                  Navigator.pop(context);
                },
                child: const Text('Add File'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(claimWizardControllerProvider(widget.initialProduct));
    final controller = ref.read(claimWizardControllerProvider(widget.initialProduct).notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload Supporting Proof',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onBackgroundDark : AppColors.onBackgroundLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Attach receipts, photos of physical damage, or failure videos (Optional, up to 20MB each):',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.gray400 : AppColors.gray600,
            ),
          ),
          const SizedBox(height: 16),

          // Priority Boost Highlight Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.secondary.withAlpha(50)),
            ),
            child: const Row(
              children: [
                Icon(Icons.stars, color: AppColors.secondary, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '+10 Priority Score boost awarded for providing proof documentation.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Add Attachment Button
          OutlinedButton.icon(
            key: const Key('wizard_upload_attachment_btn'),
            onPressed: _showAddAttachmentDialog,
            icon: const Icon(Icons.attach_file),
            label: const Text('Add Attachment (Photo, PDF, Video)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),

          // Attachments List
          if (state.attachments.isNotEmpty) ...[
            Text(
              'Attached Files (${state.attachments.length})',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.attachments.length,
              itemBuilder: (context, index) {
                final item = state.attachments[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    side: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                  ),
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined, color: AppColors.primary),
                    title: Text(
                      item.fileName,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${item.formattedSize} • ${item.mimeType}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.gray400 : AppColors.gray600,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      onPressed: () => controller.removeAttachment(index),
                    ),
                  ),
                );
              },
            ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No attachments added yet. You can proceed without attachments or add them now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.gray400 : AppColors.gray600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
