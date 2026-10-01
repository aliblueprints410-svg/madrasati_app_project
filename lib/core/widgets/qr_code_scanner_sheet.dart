import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';

class QrCodeScannerSheet extends StatefulWidget {
  const QrCodeScannerSheet({super.key});

  static Future<String?> scan(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QrCodeScannerSheet(),
    );
  }

  @override
  State<QrCodeScannerSheet> createState() => _QrCodeScannerSheetState();
}

class _QrCodeScannerSheetState extends State<QrCodeScannerSheet> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _hasScanned = false;
  bool _torchEnabled = false;
  bool _isAnalyzingGallery = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        _hasScanned = true;
        HapticFeedback.mediumImpact();
        if (mounted) {
          Navigator.of(context).pop(raw);
        }
        break;
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isAnalyzingGallery || _hasScanned) return;
    setState(() {
      _errorMessage = null;
      _isAnalyzingGallery = true;
    });

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        if (mounted) setState(() => _isAnalyzingGallery = false);
        return;
      }

      final capture = await _controller.analyzeImage(pickedFile.path);
      if (_hasScanned) return;

      if (capture != null && capture.barcodes.isNotEmpty) {
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue?.trim();
          if (raw != null && raw.isNotEmpty) {
            _hasScanned = true;
            HapticFeedback.mediumImpact();
            if (mounted) {
              Navigator.of(context).pop(raw);
            }
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isAnalyzingGallery = false;
          _errorMessage = 'لم يتم العثور على باركود واضح في الصورة المختارة';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAnalyzingGallery = false;
          _errorMessage = 'تعذّر قراءة الباركود من الصورة، يرجى المحاولة بصورة أوضح';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مسح باركود المدرسة',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'وجّه الكاميرا نحو الباركود أو اختر صورته من المعرض',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'اختيار من المعرض',
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                IconButton(
                  tooltip: 'تشغيل/إيقاف الفلاش',
                  onPressed: () async {
                    await _controller.toggleTorch();
                    if (mounted) {
                      setState(() => _torchEnabled = !_torchEnabled);
                    }
                  },
                  icon: Icon(
                    _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    color: _torchEnabled ? Colors.amber : Colors.grey,
                  ),
                ),
                IconButton(
                  tooltip: 'إغلاق',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                    // Viewfinder Frame Overlay
                    Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 3),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    if (_isAnalyzingGallery)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    Positioned(
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'سيتم قراءة الكود تلقائياً بمجرد ظهوره',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Prominent Gallery Picker Button at the bottom
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isAnalyzingGallery ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded, color: Colors.white),
                  label: const Text(
                    'مسح صورة باركود من المعرض',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
