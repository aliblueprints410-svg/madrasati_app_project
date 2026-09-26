import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../homework/models/homework.dart';
import '../../homework/providers/homework_providers.dart';

class AddHomeworkScreen extends ConsumerStatefulWidget {
  const AddHomeworkScreen({super.key});

  @override
  ConsumerState<AddHomeworkScreen> createState() => _AddHomeworkScreenState();
}

class _AddHomeworkScreenState extends ConsumerState<AddHomeworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedClassId;
  String? _selectedSubjectId;
  File? _imageFile;
  DateTime? _deadline;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/${const Uuid().v4()}.jpg';

      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        pickedFile.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (compressedImage != null) {
        setState(() => _imageFile = File(compressedImage.path));
      }
    }
  }

  Future<void> _selectDeadline() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 20, minute: 0),
      );

      if (pickedTime != null) {
        setState(() {
          _deadline = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedClassId == null || _selectedSubjectId == null || _deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('يرجى اختيار الصف والمادة، وتحديد موعد التسليم'),
            ],
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      String? imageUrl;

      bool imageUploadFailed = false;
      // Upload Image if exists to Supabase storage
      if (_imageFile != null) {
        final fileExt = _imageFile!.path.split('.').last;
        final fileName = '${const Uuid().v4()}.$fileExt';
        final filePath = 'homework_images/$fileName';

        try {
          await supabase.storage.from('school_assets').upload(filePath, _imageFile!);
          imageUrl = supabase.storage.from('school_assets').getPublicUrl(filePath);
        } catch (e) {
          imageUploadFailed = true;
          debugPrint('[AddHomework] Image upload error: $e');
        }
      }

      final newHomework = Homework(
        id: const Uuid().v4(),
        subjectId: _selectedSubjectId!,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        deadline: _deadline,
        isCurrent: true,
        isDeleted: false,
      );

      await ref.read(homeworkServiceProvider).addHomework(newHomework);

      // Send Push Notification to students
      try {
        final localStorage = ref.read(localStorageServiceProvider);
        final schoolId = AppConstants.sanitizeSchoolId(localStorage.getSchoolCode());
        await ref.read(notificationServiceProvider).sendPushNotification(
          schoolCode: schoolId,
          title: '📚 تحضير مدرسي جديد: ${_titleController.text.trim()}',
          message: _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : 'تمت إضافة تحضير/واجب جديد، يرجى مراجعته والتأكد من إنجازه.',
        );
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  imageUploadFailed
                      ? 'تم نشر الواجب بنجاح (ملاحظة: تعذر إرفاق الصورة لعدم تفعيل Storage في Supabase)'
                      : 'تم نشر التحضير بنجاح',
                ),
              ),
            ],
          ),
          backgroundColor: imageUploadFailed ? AppColors.warning : AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء النشر: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
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
        title: const Text('إضافة تحضير جديد'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'الصف والمادة الدراسية',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        // Class Selection
                        classesAsync.when(
                          data: (classes) {
                            return DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'اختر الصف',
                                prefixIcon: Icon(Icons.school_rounded),
                              ),
                              initialValue: _selectedClassId,
                              items: classes
                                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedClassId = val;
                                  _selectedSubjectId = null;
                                });
                              },
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('خطأ في جلب الصفوف: $e'),
                        ),
                        const SizedBox(height: 16),

                        // Subject Selection
                        if (_selectedClassId != null)
                          Consumer(
                            builder: (context, ref, child) {
                              final subjectsAsync = ref.watch(subjectsProvider(_selectedClassId!));
                              return subjectsAsync.when(
                                data: (subjects) {
                                  return DropdownButtonFormField<String>(
                                    decoration: const InputDecoration(
                                      labelText: 'اختر المادة',
                                      prefixIcon: Icon(Icons.menu_book_rounded),
                                    ),
                                    initialValue: _selectedSubjectId,
                                    items: subjects
                                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                                        .toList(),
                                    onChanged: (val) => setState(() => _selectedSubjectId = val),
                                  );
                                },
                                loading: () => const LinearProgressIndicator(),
                                error: (e, _) => Text('خطأ في جلب المواد: $e'),
                              );
                            },
                          ),
                        const SizedBox(height: 24),

                        const Text(
                          'بيانات التحضير والواجب',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),

                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'عنوان التحضير (مثال: حل تمارين صفحة 24)',
                            prefixIcon: Icon(Icons.title_rounded),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'يرجى كتابة عنوان التحضير' : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _descController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'تفاصيل الواجب والملاحظات للطلاب...',
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'يرجى كتابة تفاصيل الواجب' : null,
                        ),
                        const SizedBox(height: 20),

                        // Deadline Section
                        const Text(
                          'موعد انتهاء التسليم',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.calendar_today_rounded, color: AppColors.secondary),
                            title: Text(
                              _deadline != null
                                  ? DateFormat('yyyy-MM-dd • hh:mm a').format(_deadline!)
                                  : 'الموعد النهائي للحل',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text('اضغط لتحديد التاريخ والوقت', style: TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.access_time_rounded, color: Colors.amber),
                            onTap: _selectDeadline,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Image attachment
                        const Text(
                          'إرفاق صورة توضيحية (اختياري)',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_rounded),
                                label: const Text('المعرض'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt_rounded),
                                label: const Text('الكاميرا'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_imageFile != null) ...[
                          const SizedBox(height: 14),
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(_imageFile!, height: 160, width: double.infinity, fit: BoxFit.cover),
                              ),
                              IconButton(
                                icon: const CircleAvatar(
                                  backgroundColor: Colors.red,
                                  radius: 14,
                                  child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                                ),
                                onPressed: () => setState(() => _imageFile = null),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),

                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('نشر التحضير للطلاب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}