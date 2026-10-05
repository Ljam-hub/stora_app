import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/api/api_client.dart';
import '../../data/api/api_config.dart';
import '../../stora_login/theme/app_colors.dart';
import '../../stora_login/utils/snackbar.dart';
import '../models/payment_account.dart';
import '../stores/store_status_store.dart';
import '../theme/home_colors.dart';

class StorePaymentScreen extends StatefulWidget {
  const StorePaymentScreen({super.key});

  @override
  State<StorePaymentScreen> createState() => _StorePaymentScreenState();
}

class _EditableAccount {
  String label;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  Uint8List? pickedQrBytes;
  String? pickedQrFilename;
  String? existingQrUrl;
  bool qrCleared;
  bool isPrimary;
  bool isActive;

  _EditableAccount({
    required this.label,
    required String name,
    required String phone,
    this.existingQrUrl,
    this.isPrimary = false,
    this.isActive = true,
  })  : qrCleared = false,
        nameController = TextEditingController(text: name),
        phoneController = TextEditingController(text: phone);

  bool get hasQr =>
      !qrCleared &&
      (pickedQrBytes != null || (existingQrUrl != null && existingQrUrl!.isNotEmpty));

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
  }
}

class _StorePaymentScreenState extends State<StorePaymentScreen> {
  final _picker = ImagePicker();
  final List<_EditableAccount> _accounts = [];

  bool _acceptOnlinePayments = true;
  bool _showSingleAccount = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentPaymentDetails();
  }

  @override
  void dispose() {
    for (final acc in _accounts) {
      acc.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCurrentPaymentDetails() async {
    final status = StoreStatusStore.instance;
    _acceptOnlinePayments = status.acceptOnlinePayments;
    _showSingleAccount = status.showSingleAccount;

    // Load from StoreStatusStore first
    _populateFromStatus(status);

    try {
      final data = await ApiClient.instance.getStoreLocation();
      if (mounted) {
        final acceptOnlinePayments = (data['accept_gcash_payments'] is bool)
            ? (data['accept_gcash_payments'] as bool)
            : (data['accept_gcash_payments']?.toString().toLowerCase() == 'true' ||
                data['accept_gcash_payments'] == null);

        final rawShowSingle = data['show_single_account'];
        final showSingleAccount = (rawShowSingle is bool)
            ? rawShowSingle
            : (rawShowSingle?.toString().toLowerCase() == 'true');

        final rawAccounts = data['payment_accounts'];
        List<PaymentAccount> parsedAccounts = [];
        if (rawAccounts is List && rawAccounts.isNotEmpty) {
          parsedAccounts = rawAccounts
              .map((e) => PaymentAccount.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        } else {
          final phone = data['payment_phone_number']?.toString() ?? '';
          final name = data['payment_account_name']?.toString() ?? '';
          final rawQr = (data['payment_qr_url'] ?? data['payment_qr_code'])?.toString();
          final qrUrl = (rawQr != null && rawQr.isNotEmpty) ? ApiConfig.resolveMediaUrl(rawQr) : null;
          if (phone.isNotEmpty || qrUrl != null) {
            parsedAccounts = [
              PaymentAccount(
                label: 'GCash',
                accountName: name,
                accountNumber: phone,
                qrCodeUrl: qrUrl,
                isPrimary: true,
                isActive: true,
              ),
            ];
          }
        }

        for (final acc in _accounts) {
          acc.dispose();
        }
        _accounts.clear();

        if (parsedAccounts.isNotEmpty) {
          final hasPrimary = parsedAccounts.any((a) => a.isPrimary);
          for (int i = 0; i < parsedAccounts.length; i++) {
            final acc = parsedAccounts[i];
            _accounts.add(_EditableAccount(
              label: acc.label.isNotEmpty ? acc.label : 'GCash',
              name: acc.accountName,
              phone: acc.accountNumber,
              existingQrUrl: acc.qrCodeUrl,
              isPrimary: acc.isPrimary || (!hasPrimary && i == 0),
              isActive: acc.isActive,
            ));
          }
        } else {
          // Default initial empty account
          _accounts.add(_EditableAccount(
            label: 'GCash',
            name: '',
            phone: '',
            isPrimary: true,
            isActive: true,
          ));
        }

        setState(() {
          _acceptOnlinePayments = acceptOnlinePayments;
          _showSingleAccount = showSingleAccount;
          _isLoading = false;
        });

        status.updatePaymentAccounts(parsedAccounts, showSingleAccount: showSingleAccount);
        final primaryAcc = parsedAccounts.firstWhere((a) => a.isPrimary, orElse: () => parsedAccounts.isNotEmpty ? parsedAccounts.first : PaymentAccount());
        status.updatePaymentDetails(
          paymentPhoneNumber: primaryAcc.accountNumber,
          paymentAccountName: primaryAcc.accountName,
          paymentQrUrl: primaryAcc.qrCodeUrl,
          clearQrCode: primaryAcc.qrCodeUrl == null,
          acceptOnlinePayments: acceptOnlinePayments,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateFromStatus(StoreStatusStore status) {
    _showSingleAccount = status.showSingleAccount;
    for (final acc in _accounts) {
      acc.dispose();
    }
    _accounts.clear();

    if (status.paymentAccounts.isNotEmpty) {
      final hasPrimary = status.paymentAccounts.any((a) => a.isPrimary);
      for (int i = 0; i < status.paymentAccounts.length; i++) {
        final acc = status.paymentAccounts[i];
        _accounts.add(_EditableAccount(
          label: acc.label.isNotEmpty ? acc.label : 'GCash',
          name: acc.accountName,
          phone: acc.accountNumber,
          existingQrUrl: acc.qrCodeUrl,
          isPrimary: acc.isPrimary || (!hasPrimary && i == 0),
          isActive: acc.isActive,
        ));
      }
    } else {
      final phone = status.paymentPhoneNumber;
      final name = status.paymentAccountName;
      final qr = status.paymentQrUrl;
      _accounts.add(_EditableAccount(
        label: 'GCash',
        name: name,
        phone: phone,
        existingQrUrl: qr,
        isPrimary: true,
        isActive: true,
      ));
    }
  }

  void _addNewAccount() {
    if (_accounts.isNotEmpty) {
      final last = _accounts.last;
      if (last.phoneController.text.trim().isEmpty && !last.hasQr) {
        showStoraSnackBar(
          context,
          'Please configure your current ${last.label} account before adding another.',
          isError: false,
        );
        return;
      }
    }
    HapticFeedback.lightImpact();
    setState(() {
      final existingLabels = _accounts.map((a) => a.label.toLowerCase()).toSet();
      String nextLabel = 'Maya';
      if (existingLabels.contains('maya')) nextLabel = 'BPI';
      if (existingLabels.contains('bpi')) nextLabel = 'BDO';
      if (existingLabels.contains('bdo')) nextLabel = 'GoTyme';

      // Pre-fill holder name from first account if available
      final defaultName = _accounts.isNotEmpty ? _accounts.first.nameController.text.trim() : '';

      _accounts.add(_EditableAccount(
        label: nextLabel,
        name: defaultName,
        phone: '',
        isPrimary: _accounts.isEmpty,
        isActive: true,
      ));
    });
  }

  void _removeAccount(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      final removed = _accounts.removeAt(index);
      final wasPrimary = removed.isPrimary;
      removed.dispose();
      if (_accounts.isEmpty) {
        _accounts.add(_EditableAccount(label: 'GCash', name: '', phone: '', isPrimary: true, isActive: true));
      } else if (wasPrimary) {
        _accounts.first.isPrimary = true;
      }
    });
  }

  Future<void> _pickQrCode(ImageSource source, int accountIndex) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (mounted && accountIndex < _accounts.length) {
        setState(() {
          _accounts[accountIndex].pickedQrBytes = bytes;
          _accounts[accountIndex].pickedQrFilename = picked.name;
          _accounts[accountIndex].qrCleared = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showStoraSnackBar(context, 'Failed to pick image: $e', isError: true);
      }
    }
  }

  void _showImageSourceSheet(int accountIndex) {
    final acc = _accounts[accountIndex];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: HomeColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.primary),
              title: Text('Take a photo', style: TextStyle(color: HomeColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickQrCode(ImageSource.camera, accountIndex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: Text('Choose from gallery', style: TextStyle(color: HomeColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _pickQrCode(ImageSource.gallery, accountIndex);
              },
            ),
            if (acc.hasQr) ...[
              Divider(color: HomeColors.cardBorder, height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                title: const Text(
                  'Remove QR Code',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    acc.pickedQrBytes = null;
                    acc.pickedQrFilename = null;
                    acc.qrCleared = true;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (!_accounts.any((a) => a.isPrimary) && _accounts.isNotEmpty) {
        _accounts.first.isPrimary = true;
      }

      final paymentAccounts = _accounts.map((a) {
        return PaymentAccount(
          label: a.label,
          accountName: a.nameController.text.trim(),
          accountNumber: a.phoneController.text.trim(),
          isPrimary: a.isPrimary,
          isActive: a.isActive,
          qrCodeUrl: a.qrCleared ? null : a.existingQrUrl,
          pendingQrBytes: a.pickedQrBytes,
          pendingQrFilename: a.pickedQrFilename,
          qrCleared: a.qrCleared,
        );
      }).toList();

      final primary = paymentAccounts.firstWhere(
        (a) => a.isPrimary,
        orElse: () => paymentAccounts.isNotEmpty ? paymentAccounts.first : const PaymentAccount(),
      );

      final res = await ApiClient.instance.updateStorePaymentInfo(
        paymentPhoneNumber: primary.accountNumber,
        paymentAccountName: primary.accountName,
        paymentQrBytes: primary.pendingQrBytes,
        paymentQrFilename: primary.pendingQrFilename,
        clearQrCode: primary.qrCleared,
        acceptGcashPayments: _acceptOnlinePayments,
        showSingleAccount: _showSingleAccount,
        paymentAccounts: paymentAccounts,
      );

      final rawQr = (res['payment_qr_url'] ?? res['payment_qr_code'])?.toString();
      final updatedPrimaryQrUrl = (primary.qrCleared == true)
          ? null
          : ((rawQr != null && rawQr.isNotEmpty)
              ? ApiConfig.resolveMediaUrl(rawQr)
              : primary.qrCodeUrl);

      final savedAccounts = paymentAccounts.map((a) {
        return a.copyWith(
          pendingQrBytes: null,
          pendingQrFilename: null,
          qrCleared: false,
          qrCodeUrl: a.isPrimary ? updatedPrimaryQrUrl : a.qrCodeUrl,
        );
      }).toList();

      StoreStatusStore.instance.updatePaymentAccounts(savedAccounts, showSingleAccount: _showSingleAccount);
      StoreStatusStore.instance.updatePaymentDetails(
        paymentPhoneNumber: primary.accountNumber,
        paymentAccountName: primary.accountName,
        paymentQrUrl: updatedPrimaryQrUrl,
        clearQrCode: primary.qrCleared,
        acceptOnlinePayments: _acceptOnlinePayments,
      );

      if (mounted) {
        setState(() {
          for (int i = 0; i < _accounts.length; i++) {
            _accounts[i].pickedQrBytes = null;
            _accounts[i].pickedQrFilename = null;
            _accounts[i].qrCleared = false;
            if (_accounts[i].isPrimary) _accounts[i].existingQrUrl = updatedPrimaryQrUrl;
          }
        });
        showStoraSnackBar(context, 'Payment accounts saved successfully!', isError: false);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showStoraSnackBar(context, 'Failed to save: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  bool get _hasUnsavedChanges {
    final status = StoreStatusStore.instance;
    if (_showSingleAccount != status.showSingleAccount) return true;
    if (_accounts.length != status.paymentAccounts.length) return true;
    for (int i = 0; i < _accounts.length; i++) {
      final a = _accounts[i];
      if (a.pickedQrBytes != null || a.qrCleared) return true;
      if (i < status.paymentAccounts.length) {
        final saved = status.paymentAccounts[i];
        if (a.label != saved.label) return true;
        if (a.nameController.text.trim() != saved.accountName) return true;
        if (a.phoneController.text.trim() != saved.accountNumber) return true;
        if (a.isPrimary != saved.isPrimary) return true;
        if (a.isActive != saved.isActive) return true;
      }
    }
    return false;
  }

  Future<bool> _handleBackPress() async {
    if (!_hasUnsavedChanges) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: HomeColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Unsaved Changes',
            style: TextStyle(color: HomeColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'You have unsaved changes to your payment methods or QR codes. Do you want to discard them?',
          style: TextStyle(color: HomeColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep Editing', style: TextStyle(color: HomeColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: HomeColors.dangerText,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  IconData _getPaymentIcon(String label) {
    switch (label.toLowerCase()) {
      case 'gcash':
      case 'maya':
      case 'shopeepay':
        return Icons.account_balance_wallet_rounded;
      case 'bpi':
      case 'bdo':
      case 'unionbank':
      case 'metrobank':
      case 'landbank':
      case 'gotyme':
        return Icons.account_balance_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  Color _getPaymentColor(String label) {
    switch (label.toLowerCase()) {
      case 'gcash':
        return const Color(0xFF007DFE);
      case 'maya':
        return const Color(0xFF13C16C);
      case 'gotyme':
        return const Color(0xFFFF5E00);
      case 'bpi':
        return const Color(0xFFB71C1C);
      case 'bdo':
        return const Color(0xFF0D47A1);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _handleBackPress();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: HomeColors.background,
        appBar: AppBar(
          backgroundColor: HomeColors.background,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: HomeColors.textPrimary),
            onPressed: () async {
              final shouldPop = await _handleBackPress();
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            'Online Payment & QR Codes',
            style: TextStyle(
              color: HomeColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Accept Online Payments Toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: HomeColors.cardBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _acceptOnlinePayments
                                ? AppColors.primary.withValues(alpha: 0.45)
                                : HomeColors.cardBorder,
                            width: _acceptOnlinePayments ? 1.5 : 1.0,
                          ),
                          boxShadow: HomeColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _acceptOnlinePayments
                                              ? AppColors.primary.withValues(alpha: 0.15)
                                              : HomeColors.textSecondary.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _acceptOnlinePayments
                                              ? Icons.payments_rounded
                                              : Icons.money_off_rounded,
                                          color: _acceptOnlinePayments
                                              ? AppColors.primary
                                              : HomeColors.textSecondary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Accept Online Payments',
                                              style: TextStyle(
                                                color: HomeColors.textPrimary,
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _acceptOnlinePayments
                                                  ? 'Active • Displayed at customer checkout'
                                                  : 'Paused • Cash on Pickup only',
                                              style: TextStyle(
                                                color: _acceptOnlinePayments
                                                    ? const Color(0xFF34D399)
                                                    : const Color(0xFFFBBF24),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _acceptOnlinePayments,
                                  activeThumbColor: AppColors.primary,
                                  activeTrackColor: AppColors.primary.withValues(alpha: 0.38),
                                  onChanged: (val) {
                                    HapticFeedback.selectionClick();
                                    setState(() => _acceptOnlinePayments = val);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Customer Display Option Container
                      if (_acceptOnlinePayments) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: HomeColors.cardBackground,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: HomeColors.cardBorder),
                            boxShadow: HomeColors.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'CUSTOMER CHECKOUT DISPLAY',
                                    style: TextStyle(
                                      color: HomeColors.textMuted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Choose what your customers see at online checkout:',
                                style: TextStyle(
                                  color: HomeColors.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Option 1: Show all active accounts
                              InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _showSingleAccount = false);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: !_showSingleAccount
                                        ? AppColors.primary.withValues(alpha: 0.08)
                                        : HomeColors.cardElevated,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: !_showSingleAccount
                                          ? AppColors.primary
                                          : HomeColors.cardBorder,
                                      width: !_showSingleAccount ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        !_showSingleAccount
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_off_rounded,
                                        color: !_showSingleAccount
                                            ? AppColors.primary
                                            : HomeColors.textMuted,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Show all active accounts',
                                              style: TextStyle(
                                                color: HomeColors.textPrimary,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Customer can choose between GCash, Maya, Bank, etc.',
                                              style: TextStyle(
                                                color: HomeColors.textSecondary,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Option 2: Show single primary account only
                              InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _showSingleAccount = true);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _showSingleAccount
                                        ? AppColors.primary.withValues(alpha: 0.08)
                                        : HomeColors.cardElevated,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _showSingleAccount
                                          ? AppColors.primary
                                          : HomeColors.cardBorder,
                                      width: _showSingleAccount ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _showSingleAccount
                                            ? Icons.radio_button_checked_rounded
                                            : Icons.radio_button_off_rounded,
                                        color: _showSingleAccount
                                            ? AppColors.primary
                                            : HomeColors.textMuted,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Show only 1 account (Primary)',
                                              style: TextStyle(
                                                color: HomeColors.textPrimary,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Only displays your single Primary account at checkout.',
                                              style: TextStyle(
                                                color: HomeColors.textSecondary,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Guide banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.qr_code_2_rounded,
                                  color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Multiple Payment Methods',
                                    style: TextStyle(
                                      color: HomeColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Add all your e-wallets (GCash, Maya) and bank accounts (BPI, BDO). Shoppers can choose how to send money.',
                                    style: TextStyle(
                                      color: HomeColors.textSecondary,
                                      fontSize: 11.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Accounts List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PAYMENT ACCOUNTS (${_accounts.length})',
                            style: TextStyle(
                              color: HomeColors.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addNewAccount,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Add Account',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // List of Payment Account Cards
                      ...List.generate(_accounts.length, (index) {
                        return _buildAccountCard(index);
                      }),

                      const SizedBox(height: 14),

                      // Add Account Outlined Button
                      OutlinedButton.icon(
                        onPressed: _addNewAccount,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('Add Another Payment Account (GCash, Maya, Bank)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Save Payment Methods',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildAccountCard(int index) {
    final acc = _accounts[index];
    final color = _getPaymentColor(acc.label);
    final icon = _getPaymentIcon(acc.label);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomeColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomeColors.cardBorder),
        boxShadow: HomeColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Provider Label + Primary Badge + Delete Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        acc.label.toUpperCase(),
                        style: TextStyle(
                          color: HomeColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (acc.isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                            SizedBox(width: 3),
                            Text(
                              'PRIMARY',
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_accounts.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  tooltip: 'Remove Account',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _removeAccount(index),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Primary Selector & Active Toggle Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: HomeColors.cardElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HomeColors.cardBorder.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      for (final a in _accounts) {
                        a.isPrimary = false;
                      }
                      acc.isPrimary = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: acc.isPrimary
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: acc.isPrimary
                            ? const Color(0xFFF59E0B)
                            : HomeColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          acc.isPrimary ? Icons.star_rounded : Icons.star_border_rounded,
                          color: acc.isPrimary ? const Color(0xFFD97706) : HomeColors.textMuted,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          acc.isPrimary ? 'Primary Account' : 'Set as Primary',
                          style: TextStyle(
                            color: acc.isPrimary ? const Color(0xFFD97706) : HomeColors.textSecondary,
                            fontSize: 11,
                            fontWeight: acc.isPrimary ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      acc.isActive ? 'Active' : 'Hidden',
                      style: TextStyle(
                        color: acc.isActive ? const Color(0xFF10B981) : HomeColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch.adaptive(
                        value: acc.isActive,
                        activeThumbColor: const Color(0xFF10B981),
                        activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.35),
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => acc.isActive = val);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Provider Preset Selector Chips
          Text(
            'PAYMENT SERVICE / PROVIDER',
            style: TextStyle(
              color: HomeColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: PaymentAccount.presetLabels.map((preset) {
                final isSelected = acc.label.toLowerCase() == preset.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(preset),
                    selected: isSelected,
                    selectedColor: color.withValues(alpha: 0.2),
                    backgroundColor: HomeColors.cardElevated,
                    labelStyle: TextStyle(
                      color: isSelected ? color : HomeColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: isSelected ? color : HomeColors.cardBorder,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    onSelected: (val) {
                      if (val) {
                        HapticFeedback.selectionClick();
                        setState(() => acc.label = preset);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Mobile / Account Number Input
          Text(
            'ACCOUNT / MOBILE NUMBER',
            style: TextStyle(
              color: HomeColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: acc.phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: HomeColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'e.g. 0917 123 4567 or 1234-5678-90',
              hintStyle: TextStyle(color: HomeColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: HomeColors.cardElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: HomeColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                tooltip: 'Paste from clipboard',
                onPressed: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null && mounted) {
                    setState(() {
                      acc.phoneController.text = data!.text!.trim();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Account Holder Name Input
          Text(
            'ACCOUNT HOLDER NAME',
            style: TextStyle(
              color: HomeColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: acc.nameController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: HomeColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'e.g. Juan Dela Cruz',
              hintStyle: TextStyle(color: HomeColors.textMuted, fontSize: 13),
              filled: true,
              fillColor: HomeColors.cardElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: HomeColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // QR Code Image Section
          Text(
            'QR CODE IMAGE',
            style: TextStyle(
              color: HomeColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          if (acc.hasQr) ...[
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: HomeColors.cardBorder, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: acc.pickedQrBytes != null
                          ? Image.memory(acc.pickedQrBytes!, fit: BoxFit.contain)
                          : Image.network(
                              ApiConfig.resolveMediaUrl(acc.existingQrUrl) ?? acc.existingQrUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const Center(
                                child: Icon(Icons.broken_image_rounded, size: 28, color: Colors.grey),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            acc.pickedQrBytes = null;
                            acc.pickedQrFilename = null;
                            acc.qrCleared = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black87,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR Code Uploaded',
                        style: TextStyle(
                          color: HomeColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Customers can scan this to pay via ${acc.label}.',
                        style: TextStyle(color: HomeColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showImageSourceSheet(index),
                        icon: const Icon(Icons.change_circle_outlined, size: 15),
                        label: const Text('Change QR', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color.withValues(alpha: 0.4)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: () => _showImageSourceSheet(index),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: HomeColors.cardElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: color, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Upload ${acc.label} QR Code',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
