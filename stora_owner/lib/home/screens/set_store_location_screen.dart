import 'package:flutter/material.dart';
import '../../data/api/api_client.dart';
import '../../stora_login/stora_login.dart';
import '../theme/home_colors.dart';

class SetStoreLocationScreen extends StatefulWidget {
  const SetStoreLocationScreen({super.key});

  @override
  State<SetStoreLocationScreen> createState() => _SetStoreLocationScreenState();
}

class _SetStoreLocationScreenState extends State<SetStoreLocationScreen> {
  final _addressController = TextEditingController();
  final _latController = TextEditingController(text: '14.5995');
  final _lngController = TextEditingController(text: '120.9842');

  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;
  bool _isError = false;

  // Preset location quick picks in the Philippines for easy testing/setup
  final List<Map<String, dynamic>> _quickLocations = [
    {
      'label': 'Manila (City Center)',
      'address': 'Rizal Ave, Santa Cruz, Manila, Metro Manila',
      'lat': 14.5995,
      'lng': 120.9842,
    },
    {
      'label': 'Quezon City',
      'address': 'Diliman, Quezon City, Metro Manila',
      'lat': 14.6538,
      'lng': 121.0685,
    },
    {
      'label': 'Makati (Poblacion)',
      'address': 'Poblacion, Makati, Metro Manila',
      'lat': 14.5647,
      'lng': 121.0336,
    },
    {
      'label': 'Pasig (Kapitolyo)',
      'address': 'Kapitolyo, Pasig, Metro Manila',
      'lat': 14.5746,
      'lng': 121.0583,
    },
    {
      'label': 'Cebu City',
      'address': 'Colon St, Cebu City, Cebu',
      'lat': 10.3157,
      'lng': 123.8854,
    },
    {
      'label': 'Davao City',
      'address': 'San Pedro St, Davao City, Davao del Sur',
      'lat': 7.1907,
      'lng': 125.4553,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiClient.instance.getStoreLocation();
      if (mounted) {
        setState(() {
          _latController.text = (data['latitude'] ?? 14.5995).toString();
          _lngController.text = (data['longitude'] ?? 120.9842).toString();
          _addressController.text = (data['address'] ?? '').toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveLocation() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final address = _addressController.text.trim();

    if (lat == null || lng == null) {
      setState(() {
        _isError = true;
        _message = 'Please enter valid numeric latitude and longitude.';
      });
      return;
    }

    if (address.isEmpty) {
      setState(() {
        _isError = true;
        _message = 'Please enter a physical store address.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      await ApiClient.instance.updateStoreLocation(
        latitude: lat,
        longitude: lng,
        address: address,
      );
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isError = false;
          _message = 'Store location pinned successfully! Customers can now find you on their map.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: HomeColors.successBg,
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: HomeColors.successText),
                SizedBox(width: 10),
                Text('Location saved and visible on map!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isError = true;
          _message = e.toString().replaceAll('ApiException: ', '');
        });
      }
    }
  }

  void _applyQuickLocation(Map<String, dynamic> loc) {
    setState(() {
      _latController.text = loc['lat'].toString();
      _lngController.text = loc['lng'].toString();
      _addressController.text = loc['address'].toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Row(
          children: [
            Icon(Icons.location_on_rounded, color: AppColors.purpleLight, size: 20),
            SizedBox(width: 8),
            Text(
              'Set Store Location',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.purpleLight))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Map Preview Canvas Card matching Stitch Set Store Location Screen
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161224),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: HomeColors.cardBorderLight.withValues(alpha: 0.6)),
                      boxShadow: HomeColors.cardShadow,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Stylized Map Grid Canvas Background
                        CustomPaint(
                          size: const Size(double.infinity, 220),
                          painter: _MapGridPainter(),
                        ),
                        // Center Pin marker with pulse animation
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.purpleLight, width: 1),
                                ),
                                child: const Text(
                                  'Your Store Pin',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: HomeColors.purpleGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: HomeColors.glowShadow(AppColors.purple, opacity: 0.6),
                                ),
                                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                              ),
                              Container(
                                width: 4,
                                height: 8,
                                color: AppColors.purpleLight,
                              ),
                              Container(
                                width: 12,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Overlay badge at top-left
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.public_rounded, color: AppColors.purpleLight, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'GPS Coordinate Mapping',
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Info note
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: HomeColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: HomeColors.cardBorder),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.visibility_outlined, color: AppColors.purpleLight, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Customers browsing the Stora Customer app will see your store marker and can order directly from you.',
                            style: TextStyle(color: AppColors.label, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick City Presets
                  const Text(
                    'QUICK PRESETS (PHILIPPINES)',
                    style: TextStyle(
                      color: AppColors.label,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickLocations.length,
                      itemBuilder: (context, index) {
                        final loc = _quickLocations[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            avatar: const Icon(Icons.place_rounded, size: 14, color: AppColors.purpleLight),
                            label: Text(loc['label'] as String),
                            backgroundColor: HomeColors.cardBackground,
                            side: const BorderSide(color: HomeColors.cardBorder),
                            labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onPressed: () => _applyQuickLocation(loc),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Address Input
                  const Text(
                    'STORE PHYSICAL ADDRESS',
                    style: TextStyle(
                      color: AppColors.label,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g., 123 Bgy. Santo Cristo, Sari-Sari Store Row',
                      hintStyle: const TextStyle(color: AppColors.label),
                      prefixIcon: const Icon(Icons.home_work_outlined, color: AppColors.purpleLight),
                      filled: true,
                      fillColor: HomeColors.cardBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: HomeColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: HomeColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.purpleLight, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Lat & Lng Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LATITUDE',
                              style: TextStyle(color: AppColors.label, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _latController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: HomeColors.cardBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: HomeColors.cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: HomeColors.cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.purpleLight),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LONGITUDE',
                              style: TextStyle(color: AppColors.label, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _lngController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: HomeColors.cardBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: HomeColors.cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: HomeColors.cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.purpleLight),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isError ? HomeColors.dangerBg : HomeColors.successBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isError ? AppColors.error : HomeColors.successText,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _isError ? const Color(0xFFFF9B9B) : const Color(0xFFA7F3D0),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Save Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveLocation,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                      label: Text(
                        _isSaving ? 'Saving Location...' : 'Pin & Save Store Location',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF130E22);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Stylized map roads
    final roadPaint = Paint()
      ..color = const Color(0xFF2C2346)
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.65),
      roadPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.55, size.height),
      roadPaint,
    );

    // Accent line
    final roadCenter = Paint()
      ..color = const Color(0xFF4C3E75)
      ..strokeWidth = 2.0;

    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.65),
      roadCenter,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
