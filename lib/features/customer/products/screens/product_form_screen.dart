import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_breakpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/supabase_client.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/warranty_calculator.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_content_wrapper.dart';
import '../controllers/products_controller.dart';
import '../models/product_model.dart';
import '../repositories/product_repository.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId; // null for new, non-null for edit

  const ProductFormScreen({
    super.key,
    this.productId,
  });

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _serialController = TextEditingController();
  final _purchaseDateController = TextEditingController();
  final _warrantyMonthsController = TextEditingController(text: '12');
  final _retailerController = TextEditingController();
  final _notesController = TextEditingController();

  String _category = 'Electronics';
  DateTime _purchaseDate = DateTime.now();
  int _warrantyMonths = 12;
  bool _isLoading = false;
  bool _isInitLoaded = false;
  String? _errorMessage;

  static const List<String> _categories = [
    'Electronics',
    'Home Appliances',
    'Automotive',
    'Furniture',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _purchaseDateController.text = _purchaseDate.toIso8601String().split('T')[0];
    if (widget.productId != null) {
      _loadExistingProduct();
    }
  }

  Future<void> _loadExistingProduct() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(productRepositoryProvider);
      final product = await repo.getProductById(widget.productId!);
      if (!mounted) return;

      setState(() {
        _nameController.text = product.name;
        _brandController.text = product.brand ?? '';
        _modelController.text = product.modelNumber ?? '';
        _serialController.text = product.serialNumber ?? '';
        _category = product.category;
        _purchaseDate = product.purchaseDate;
        _purchaseDateController.text = product.purchaseDate.toIso8601String().split('T')[0];
        _warrantyMonths = product.warrantyPeriodMonths;
        _warrantyMonthsController.text = product.warrantyPeriodMonths.toString();
        _retailerController.text = product.retailer ?? '';
        _notesController.text = product.notes ?? '';
        _isInitLoaded = true;
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

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _purchaseDateController.dispose();
    _warrantyMonthsController.dispose();
    _retailerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime get _calculatedExpiryDate {
    return WarrantyCalculator.calculateExpiryDate(_purchaseDate, _warrantyMonths);
  }

  Future<void> _selectPurchaseDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _purchaseDate = picked;
        _purchaseDateController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserProvider)?.id ?? '';
    final months = int.tryParse(_warrantyMonthsController.text.trim()) ?? 12;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final product = ProductModel(
        id: widget.productId ?? '',
        userId: userId,
        name: _nameController.text.trim(),
        category: _category,
        brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        modelNumber: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
        serialNumber: _serialController.text.trim().isEmpty ? null : _serialController.text.trim(),
        purchaseDate: _purchaseDate,
        warrantyPeriodMonths: months,
        warrantyExpiryDate: _calculatedExpiryDate,
        retailer: _retailerController.text.trim().isEmpty ? null : _retailerController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final controller = ref.read(productsControllerProvider.notifier);
      if (widget.productId != null) {
        await controller.updateProduct(product);
      } else {
        await controller.addProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.productId != null ? 'Product updated successfully' : 'Product registered successfully',
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('ServerException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.productId != null;

    if (isEditing && _isLoading && !_isInitLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Product')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Register Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: ResponsiveContentWrapper(
          maxWidth: AppBreakpoints.maxFormWidth,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withAlpha(77)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Product Name
                AppTextField(
                  controller: _nameController,
                  fieldKey: const Key('product_name_input'),
                  label: 'Product Name *',
                  hint: 'e.g. MacBook Pro 16", Samsung Galaxy S24',
                  validator: FormValidators.requiredField,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category *',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray700,
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    DropdownButtonFormField<String>(
                      key: const Key('product_category_dropdown'),
                      initialValue: _category,
                      isExpanded: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Brand & Model Adaptive Row/Column
                LayoutBuilder(
                  builder: (context, constraints) {
                    final brandField = AppTextField(
                      controller: _brandController,
                      fieldKey: const Key('product_brand_input'),
                      label: 'Brand',
                      hint: 'e.g. Apple, Sony',
                      textInputAction: TextInputAction.next,
                    );
                    final modelField = AppTextField(
                      controller: _modelController,
                      fieldKey: const Key('product_model_input'),
                      label: 'Model Number',
                      hint: 'e.g. A2485',
                      textInputAction: TextInputAction.next,
                    );

                    if (constraints.maxWidth < 450) {
                      return Column(
                        children: [
                          brandField,
                          const SizedBox(height: 16),
                          modelField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: brandField),
                        const SizedBox(width: 12),
                        Expanded(child: modelField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Serial Number
                AppTextField(
                  controller: _serialController,
                  fieldKey: const Key('product_serial_input'),
                  label: 'Serial Number',
                  hint: 'Found on device or packaging',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Purchase Date & Warranty Period Adaptive Row/Column
                LayoutBuilder(
                  builder: (context, constraints) {
                    final dateField = GestureDetector(
                      onTap: () => _selectPurchaseDate(context),
                      child: AbsorbPointer(
                        child: AppTextField(
                          controller: _purchaseDateController,
                          fieldKey: const Key('product_purchase_date_input'),
                          label: 'Purchase Date *',
                          hint: 'YYYY-MM-DD',
                          prefixIcon: const Icon(Icons.calendar_today, size: 18),
                          validator: FormValidators.requiredField,
                        ),
                      ),
                    );
                    final warrantyField = AppTextField(
                      controller: _warrantyMonthsController,
                      fieldKey: const Key('product_warranty_months_input'),
                      label: 'Warranty (Months) *',
                      hint: '12',
                      keyboardType: TextInputType.number,
                      validator: FormValidators.warrantyPeriod,
                      onChanged: (val) {
                        final m = int.tryParse(val.trim());
                        if (m != null && m > 0) {
                          setState(() => _warrantyMonths = m);
                        }
                      },
                    );

                    if (constraints.maxWidth < 450) {
                      return Column(
                        children: [
                          dateField,
                          const SizedBox(height: 16),
                          warrantyField,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: dateField),
                        const SizedBox(width: 12),
                        Expanded(child: warrantyField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Live Expiry Date Preview Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calculated Warranty Expiry',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormatter.formatDisplayDate(_calculatedExpiryDate),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Retailer
                AppTextField(
                  controller: _retailerController,
                  fieldKey: const Key('product_retailer_input'),
                  label: 'Retailer / Store',
                  hint: 'e.g. Best Buy, Amazon',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Notes
                AppTextField(
                  controller: _notesController,
                  label: 'Notes',
                  hint: 'Add any extra purchase or warranty info',
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 28),

                // Save Button
                AppButton(
                  buttonKey: const Key('product_save_btn'),
                  text: isEditing ? 'Save Changes' : 'Register Product',
                  onPressed: _isLoading ? null : _handleSave,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
