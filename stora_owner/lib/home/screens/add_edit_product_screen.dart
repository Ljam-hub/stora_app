import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/stores/account_status_store.dart';
import '../../subscription/subscription_screen.dart';
import '../../stora_login/stora_login.dart';
import '../models/product.dart';
import '../stores/category_store.dart';
import 'barcode_scanner_screen.dart';
import '../stores/inventory_store.dart';
import '../theme/home_colors.dart';
import '../utils/constants.dart';

// NOTE: this file uses the `image_picker` package for product photos.
// Add this to pubspec.yaml if it isn't there yet:
//
//   dependencies:
//     image_picker: ^1.1.2
//
// (Android/iOS also need the usual gallery/photo-library permission entries,
// which the image_picker docs walk through.)
//
// Images are read into memory (Uint8List) and shown with Image.memory /
// MemoryImage instead of File paths. Some platforms (web in particular)
// hand back a path that dart:io's File can't actually open, which is the
// most common reason a picked photo silently fails to show up — reading
// bytes directly sidesteps that.

class AddEditProductScreen extends StatefulWidget {
  final Product? existing;
  const AddEditProductScreen({super.key, this.existing});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _barcodeController;
  String? _category;
  Uint8List? _imageBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _stockController = TextEditingController(text: p?.stock.toString() ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _category = p?.category;
    _imageBytes = p?.imageBytes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null;

  String? _validatePrice(String? v) {
    if (v == null || v.trim().isEmpty) return 'Price is required';
    if (double.tryParse(v.trim()) == null) return 'Enter a valid amount';
    return null;
  }

  String? _validateStock(String? v) {
    if (v == null || v.trim().isEmpty) return 'Stock is required';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Enter a whole number';
    if (n < 0) return 'Stock can\'t be negative';
    if (n > kMaxStock) return 'Stock can\'t exceed $kMaxStock';
    return null;
  }

  Future<void> _save() async {
    if (widget.existing == null && !AccountStatusStore.instance.canAddProduct) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SubscriptionScreen(
            productsUsed: AccountStatusStore.instance.productCount,
            productsLimit: AccountStatusStore.instance.productLimit,
          ),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      showStoraSnackBar(context, 'Please fix the errors above');
      return;
    }

    if (_category == null || _category!.isEmpty) {
      showStoraSnackBar(context, 'Please select or add a category');
      return;
    }

    final name = _nameController.text.trim();
    final category = _category!;
    final price = double.parse(_priceController.text.trim());
    final stock = int.parse(_stockController.text.trim()).clamp(0, kMaxStock);
    final barcode = _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim();

    setState(() => _saving = true);
    try {
      final store = InventoryStore.instance;
      if (widget.existing != null) {
        widget.existing!
          ..name = name
          ..category = category
          ..price = price
          ..stock = stock
          ..barcode = barcode
          ..imageBytes = _imageBytes;
      }
      final ok = widget.existing != null
          ? await store.updateProduct(widget.existing!)
          : await store.addProduct(Product(
              id: '',
              name: name,
              category: category,
              price: price,
              stock: stock,
              barcode: barcode,
              imageBytes: _imageBytes,
            ));

      if (!mounted) return;
      if (!ok) {
        showStoraSnackBar(context, store.error ?? 'Could not save product');
        return;
      }
      showStoraSnackBar(
        context,
        widget.existing != null ? 'Product updated' : 'Product added',
        isError: false,
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _delete() {
    final product = widget.existing;
    if (product == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        title: const Text('Delete product?', style: TextStyle(color: Colors.white)),
        content: Text('This will remove "${product.name}" from your inventory. This can\'t be undone.',
            style: const TextStyle(color: AppColors.label)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
          ),
          TextButton(
            onPressed: () async {
              final ok = await InventoryStore.instance.removeProduct(product.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (!mounted) return;
              if (!ok) {
                showStoraSnackBar(
                  context,
                  InventoryStore.instance.error ?? 'Could not delete product',
                );
                return;
              }
              Navigator.of(context).pop();
              showStoraSnackBar(context, 'Product deleted', isError: false);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: HomeColors.cardBackground,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        isEditing ? 'Edit product' : 'Add product',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (isEditing)
                      IconButton(
                        onPressed: _delete,
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                        style: IconButton.styleFrom(
                          backgroundColor: HomeColors.cardBackground,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 24),
                StoraTextField(
                  label: 'Product name',
                  hint: 'e.g. Coca-Cola',
                  controller: _nameController,
                  validator: _required,
                ),
                const SizedBox(height: 18),
                _CategoryPicker(
                  initialValue: _category,
                  onChanged: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 18),
                StoraTextField(
                  label: 'Price',
                  hint: '₱0.00',
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: _validatePrice,
                ),
                const SizedBox(height: 18),
                StoraTextField(
                  label: 'Stock (max $kMaxStock)',
                  hint: '0',
                  controller: _stockController,
                  keyboardType: TextInputType.number,
                  validator: _validateStock,
                ),
                const SizedBox(height: 18),
                _BarcodeField(
                      controller: _barcodeController,
                      onScan: () async {
                        final code = await Navigator.of(context).push<String>(
                          MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                        );
                        if (code != null) {
                          _barcodeController.text = code;
                        }
                      },
                    ),
                const SizedBox(height: 18),
                _ImagePickerField(
                  initialBytes: _imageBytes,
                  onChanged: (bytes) => setState(() => _imageBytes = bytes),
                ),
                const SizedBox(height: 28),
                StoraGradientButton(
                  label: isEditing ? 'Save changes' : 'Add product',
                  isLoading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Category picker — dropdown over CategoryStore's full list (including
// hidden ones, since hiding only affects the filter chip row — a
// product should still be assignable to a hidden category), plus an
// "Add new category" entry that opens a small dialog. Whatever the
// user types gets added to the shared list and selected immediately.
// ---------------------------------------------------------------------
class _CategoryPicker extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;
  const _CategoryPicker({this.initialValue, required this.onChanged});

  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  static const _addNewValue = '__add_new__';
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  Future<void> _promptNewCategory() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        title: const Text('New category', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Frozen Goods',
            hintStyle: TextStyle(color: AppColors.hint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.label)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add', style: TextStyle(color: AppColors.purpleLight, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await CategoryStore.instance.addCategory(result);
      if (!mounted) return;
      setState(() => _selected = result);
      widget.onChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CategoryStore.instance,
      builder: (context, _) {
        final categories = CategoryStore.instance.categories;
        final dropdownValue = (_selected != null && categories.contains(_selected)) ? _selected : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CATEGORY',
                style: TextStyle(color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('${dropdownValue}_${categories.length}'),
              initialValue: dropdownValue,
              dropdownColor: HomeColors.cardBackground,
              isExpanded: true,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.label),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.fieldBackground,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                hintText: 'Select a category',
                hintStyle: const TextStyle(color: AppColors.hint),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
                ),
              ),
              items: [
                ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))),
                const DropdownMenuItem(
                  value: _addNewValue,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: AppColors.purpleLight),
                      SizedBox(width: 6),
                      Text('Add new category', style: TextStyle(color: AppColors.purpleLight, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              validator: (v) => (v == null || v.isEmpty) ? 'Please select a category' : null,
              onChanged: (value) {
                if (value == _addNewValue) {
                  _promptNewCategory();
                } else if (value != null) {
                  setState(() => _selected = value);
                  widget.onChanged(value);
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _BarcodeField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onScan;
  const _BarcodeField({required this.controller, this.onScan});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('BARCODE',
            style: TextStyle(color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Enter or scan barcode',
            hintStyle: const TextStyle(color: AppColors.hint),
            filled: true,
            fillColor: AppColors.fieldBackground,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.purpleLight),
              onPressed: onScan,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// Product image picker — pulls a photo from the gallery via
// image_picker and previews it; tap the × to clear the selection.
// ---------------------------------------------------------------------
class _ImagePickerField extends StatefulWidget {
  final Uint8List? initialBytes;
  final ValueChanged<Uint8List?> onChanged;
  const _ImagePickerField({this.initialBytes, required this.onChanged});

  @override
  State<_ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<_ImagePickerField> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes;
  }

  Future<void> _pickImage() async {
    setState(() => _loading = true);
    try {
      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1200);
      if (picked != null) {
        // Reading bytes (instead of relying on picked.path + File) works
        // consistently across mobile, desktop, and web.
        final bytes = await picked.readAsBytes();
        setState(() => _bytes = bytes);
        widget.onChanged(bytes);
      }
    } catch (_) {
      if (mounted) {
        showStoraSnackBar(context, 'Could not open the image picker');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearImage() {
    setState(() => _bytes = null);
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('IMAGE',
            style: TextStyle(color: AppColors.label, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _loading ? null : _pickImage,
          child: Container(
            width: double.infinity,
            height: 130,
            decoration: BoxDecoration(
              color: AppColors.fieldBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.fieldBorder, width: 1.2),
              image: _bytes != null
                  ? DecorationImage(image: MemoryImage(_bytes!), fit: BoxFit.cover)
                  : null,
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.purpleLight, strokeWidth: 2))
                : _bytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_rounded, color: AppColors.purpleLight, size: 24),
                          SizedBox(height: 6),
                          Text('+ Select Image',
                              style: TextStyle(color: AppColors.purpleLight, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: GestureDetector(
                            onTap: _clearImage,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}
