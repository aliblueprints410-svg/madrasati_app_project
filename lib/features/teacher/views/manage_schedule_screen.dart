import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../homework/providers/homework_providers.dart';
import '../../schedule/providers/schedule_providers.dart';

class ManageScheduleScreen extends ConsumerStatefulWidget {
  const ManageScheduleScreen({super.key});

  @override
  ConsumerState<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends ConsumerState<ManageScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  File? _imageFile;
  String? _selectedClassId;

  // Digital Schedule Fields
  final _csvTextController = TextEditingController();
  Map<String, List<String>> _parsedSchedule = {};
  String? _uploadedFileName;

  final String _defaultTemplate = '''الأحد, رياضيات, لغة عربية, علوم, إنجليزي, تربية إسلامية
الإثنين, لغة عربية, رياضيات, اجتماعيات, علوم, تربية فنية
الثلاثاء, إنجليزي, رياضيات, لغة عربية, تربية رياضية, علوم
الأربعاء, تربية إسلامية, لغة عربية, رياضيات, علوم, إنجليزي
الخميس, اجتماعيات, لغة عربية, رياضيات, حاسوب, نشاط''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _csvTextController.text = _defaultTemplate;
    _parseCsvText(_defaultTemplate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _csvTextController.dispose();
    super.dispose();
  }

  void _parseCsvText(String text) {
    final lines = const LineSplitter().convert(text);
    final result = <String, List<String>>{};

    for (var rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      // Support comma, semicolon, or tab separation
      final parts = line.split(RegExp(r'[,;\t]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (parts.length >= 2) {
        final day = parts[0];
        if (day == 'اليوم' || day.toLowerCase() == 'day') continue;
        result[day] = parts.sublist(1);
      }
    }

    setState(() {
      _parsedSchedule = result;
    });
  }

  Future<void> _pickScheduleFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'tsv', 'json'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        final content = await file.readAsString();
        setState(() {
          _uploadedFileName = files.first.name;
          _csvTextController.text = content;
        });
        _parseCsvText(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم استيراد ملف الجدول بنجاح: ${files.first.name}'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في قراءة ملف الجدول: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

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
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الصف الدراسي أولاً')),
      );
      return;
    }

    final isDigitalMode = _tabController.index == 0;

    if (isDigitalMode && _parsedSchedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التأكد من إدخال أو رفع بيانات الجدول')),
      );
      return;
    }

    if (!isDigitalMode && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد صورة الجدول من المعرض أولاً')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final localStorage = ref.read(localStorageServiceProvider);
      final schoolId = AppConstants.sanitizeSchoolId(localStorage.getSchoolCode());

      String schedulePayload;

      if (isDigitalMode) {
        // Save structured digital table as JSON
        schedulePayload = jsonEncode({
          'type': 'table',
          'data': _parsedSchedule,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Save Image (Supabase storage or compressed base64)
        String? finalImageData;
        final fileName = 'schedule_${_selectedClassId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        try {
          await supabase.storage.from('school_assets').upload(fileName, _imageFile!);
          finalImageData = supabase.storage.from('school_assets').getPublicUrl(fileName);
        } catch (storageError) {
          debugPrint('[ManageScheduleScreen] Storage bucket fallback: $storageError');
        }

        if (finalImageData == null || finalImageData.isEmpty) {
          final compressedBytes = await FlutterImageCompress.compressWithFile(
            _imageFile!.absolute.path,
            minWidth: 900,
            minHeight: 900,
            quality: 65,
            format: CompressFormat.jpeg,
          );
          final bytes = compressedBytes ?? await _imageFile!.readAsBytes();
          finalImageData = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }

        schedulePayload = finalImageData;
      }

      // 1. Save locally in SharedPreferences for instant responsiveness
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$kLocalScheduleKeyPrefix$_selectedClassId', schedulePayload);
      } catch (_) {}

      // 2. Try updating classes table
      try {
        await supabase
            .from('classes')
            .update({'schedule_image_url': schedulePayload})
            .eq('id', _selectedClassId!);
      } catch (_) {}

      // 3. Try updating schedules table with structured data
      try {
        final existingSched = await supabase
            .from('schedules')
            .select('id')
            .eq('class_id', _selectedClassId!)
            .maybeSingle();

        final schedDataMap = isDigitalMode
            ? {'type': 'table', 'data': _parsedSchedule}
            : {'image_url': schedulePayload};

        if (existingSched != null) {
          await supabase
              .from('schedules')
              .update({'schedule_data': schedDataMap})
              .eq('class_id', _selectedClassId!);
        } else {
          await supabase.from('schedules').insert({
            'id': const Uuid().v4(),
            'class_id': _selectedClassId!,
            'schedule_data': schedDataMap,
          });
        }
      } catch (_) {}

      // 4. Save to announcements cloud system record
      try {
        final sysTitle = '$kSysSchedulePrefix$_selectedClassId';
        await supabase.from('announcements').insert({
          'id': const Uuid().v4(),
          'school_id': schoolId,
          'title': sysTitle,
          'content': schedulePayload,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'priority': false,
          'is_deleted': false,
        });
      } catch (e) {
        debugPrint('[ManageScheduleScreen] Cloud schedule sync notice: $e');
      }

      // 5. Invalidate Riverpod cache
      ref.invalidate(classScheduleImageProvider(_selectedClassId!));

      // 6. Send OneSignal Push Notification exclusively to this class
      try {
        await ref.read(notificationServiceProvider).sendPushNotification(
          schoolCode: schoolId,
          classId: _selectedClassId,
          title: '📅 تم تحديث جدول الحصص الأسبوعي',
          message: isDigitalMode
              ? 'قام المعلم بنشر جدول الحصص الذكي الجديد لصفكم، تفقده الآن!'
              : 'قام المعلم بتحديث صورة جدول الحصص لصفكم، تفقده الآن!',
          additionalData: {'type': 'schedule', 'class_id': _selectedClassId},
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
                  isDigitalMode
                      ? 'تم تحويل ونشر جدول الحصص الذكي بنجاح وإرسال الإشعار للطلبة!'
                      : 'تم رفع ونشر صورة الجدول بنجاح وإرسال الإشعار للطلبة!',
                ),
              ),
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
        SnackBar(content: Text('خطأ أثناء حفظ الجدول: $e'), backgroundColor: Colors.red),
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
        title: const Text('إدارة جدول الحصص الأسبوعي', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_customize_rounded), text: 'جدول رقمي ذكي (ملف/نص)'),
            Tab(icon: Icon(Icons.image_rounded), text: 'صورة الجدول'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              // Class Selector Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: classesAsync.when(
                  data: (classes) {
                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'اختر الصف الدراسي المراد تحديث جدوله',
                        prefixIcon: const Icon(Icons.school_rounded, color: AppColors.primary),
                        filled: true,
                        fillColor: isDark ? AppColors.darkCard : Colors.grey.shade50,
                      ),
                      initialValue: _selectedClassId,
                      items: classes
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                          .toList(),
                      onChanged: (val) => setState(() => _selectedClassId = val),
                    );
                  },
                  loading: () => const Center(child: LinearProgressIndicator()),
                  error: (e, _) => Text('خطأ في جلب الصفوف: $e'),
                ),
              ),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Digital Schedule Dashboard
                    _buildDigitalScheduleTab(isDark),
                    // Tab 2: Image Schedule
                    _buildImageScheduleTab(isDark),
                  ],
                ),
              ),

              // Bottom Submit Action
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _uploadAndSave,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isLoading ? 'جاري الحفظ وإرسال الإشعار...' : 'حفظ ونشر الجدول وإشعار الطلاب',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitalScheduleTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الصيغة المثلى لرفع الجدول:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ملف Excel (CSV) أو نص منظم: (اليوم، الحصة 1، الحصة 2...). يقوم التطبيق بقراءته وتحويله تلقائياً لـ Dashboard تفاعلي للطلبة.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Upload File or Template Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickScheduleFile,
                  icon: const Icon(Icons.file_upload_outlined, size: 18),
                  label: Text(_uploadedFileName ?? 'رفع ملف Excel / CSV'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'إعادة ضبط القالب الافتراضي',
                onPressed: () {
                  _csvTextController.text = _defaultTemplate;
                  _parseCsvText(_defaultTemplate);
                },
                icon: const Icon(Icons.restore_rounded),
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live Text Editor / Input
          TextFormField(
            controller: _csvTextController,
            maxLines: 5,
            onChanged: _parseCsvText,
            decoration: InputDecoration(
              labelText: 'محرر بيانات الجدول (اليوم، الحصص مفصولة بفارزة)',
              alignLabelWithHint: true,
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 20),

          // Live Table Dashboard Preview
          const Row(
            children: [
              Icon(Icons.visibility_rounded, size: 18, color: AppColors.secondary),
              SizedBox(width: 6),
              Text(
                'معاينة Dashboard الحصص المقروءة:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_parsedSchedule.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('لم يتم التعرف على حصص بعد، يرجى كتابة الأيام والحصص أو رفع الملف'),
              ),
            )
          else
            ..._parsedSchedule.entries.map((entry) {
              final day = entry.key;
              final subjects = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            day,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${subjects.length} حصص',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: subjects.asMap().entries.map((subEntry) {
                        final periodIdx = subEntry.key + 1;
                        final subName = subEntry.value;
                        return Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                          avatar: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            radius: 10,
                            child: Text(
                              '$periodIdx',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          label: Text(
                            subName,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildImageScheduleTab(bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
        ],
      ),
    );
  }
}