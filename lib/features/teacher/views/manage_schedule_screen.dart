import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../homework/providers/homework_providers.dart';

class ManageScheduleScreen extends ConsumerStatefulWidget {
  const ManageScheduleScreen({super.key});

  @override
  ConsumerState<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends ConsumerState<ManageScheduleScreen> {
  bool _isLoading = false;
  File? _imageFile;
  String? _selectedClassId;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadAndSave() async {
    if (_imageFile == null || _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الصف وتحديد صورة الجدول أولاً')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final fileName = 'schedule_${_selectedClassId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload image to Supabase Storage
      try {
        await supabase.storage.from('school_assets').upload(fileName, _imageFile!);
        final imageUrl = supabase.storage.from('school_assets').getPublicUrl(fileName);

        // Save URL to the selected class
        await supabase.from('classes').update({'schedule_image_url': imageUrl}).eq('id', _selectedClassId!);
      } catch (e) {
        throw Exception('لم يتم العثور على مساحة تخزين الصور (school_assets) في Supabase. يرجى إنشاء Bucket باسم school_assets وجعله Public.');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('تم رفع وتحديث جدول الحصص بنجاح!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء رفع الجدول: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = AppConstants.sanitizeSchoolId(ref.watch(localStorageServiceProvider).getSchoolCode());
    final classesAsync = ref.watch(classesProvider(schoolId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعديل جدول الحصص'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                classesAsync.when(
                  data: (classes) {
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'اختر الصف الدراسي',
                        prefixIcon: Icon(Icons.school_rounded),
                      ),
                      initialValue: _selectedClassId,
                      items: classes
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedClassId = val),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('خطأ في جلب الصفوف: $e'),
                ),
                const SizedBox(height: 24),

                // Image upload container
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 240,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 2,
                      ),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, size: 54, color: AppColors.primary.withValues(alpha: 0.6)),
                              const SizedBox(height: 12),
                              const Text('لم يتم اختيار صورة بعد', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const Text(
                                'اضغط هنا لاختيار صورة جدول الحصص من المعرض',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _uploadAndSave,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: Text(_imageFile == null ? 'اختيار صورة الجدول وحفظها' : 'حفظ ونشر الجدول'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}