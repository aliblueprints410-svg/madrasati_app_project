import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/subject_visual_helper.dart';
import '../../../homework/models/subject.dart';
import '../../../homework/providers/homework_providers.dart';

class ManageSubjectsScreen extends ConsumerStatefulWidget {
  const ManageSubjectsScreen({super.key});

  @override
  ConsumerState<ManageSubjectsScreen> createState() => _ManageSubjectsScreenState();
}

class _ManageSubjectsScreenState extends ConsumerState<ManageSubjectsScreen> {
  String? _selectedClassId;
  String? _selectedClassName;
  bool _isAutoSeeding = false;

  Future<void> _addOrEditSubject(BuildContext context, {Subject? existingSubject}) async {
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار الصف أولاً')));
      return;
    }

    final initialText = existingSubject?.name ?? '';
    final nameController = TextEditingController(text: initialText)
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: initialText.length),
      );

    await showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            existingSubject == null ? 'إضافة مادة جديدة' : 'تعديل اسم المادة',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'sans-serif',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(hintText: 'مثال: التربية الفنية، الحاسوب...'),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              try {
                final homeworkService = ref.read(homeworkServiceProvider);
                if (existingSubject == null) {
                  await homeworkService.addSubject(
                    _selectedClassId!,
                    nameController.text.trim(),
                  );
                } else {
                  await homeworkService.updateSubject(
                    _selectedClassId!,
                    existingSubject.id,
                    nameController.text.trim(),
                    oldName: existingSubject.name,
                  );
                }

                ref.invalidate(subjectsProvider(_selectedClassId!));
                await ref.read(subjectsProvider(_selectedClassId!).future);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(existingSubject == null
                          ? 'تمت إضافة المادة بنجاح'
                          : 'تم تعديل اسم المادة بنجاح'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _autoSeedPrimarySubjects(BuildContext context) async {
    if (_selectedClassId == null || _selectedClassName == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('توليد المواد الرسمية تلقائياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('هل تريد إضافة المواد الوزارية المعتمدة تلقائياً لـ (${_selectedClassName!}) في قاعدة البيانات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('نعم، توليد المواد'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isAutoSeeding = true);
    try {
      final homeworkService = ref.read(homeworkServiceProvider);
      await homeworkService.seedDefaultSubjectsForClass(_selectedClassId!, _selectedClassName!);
      ref.invalidate(subjectsProvider(_selectedClassId!));
      await ref.read(subjectsProvider(_selectedClassId!).future);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم توليد وإضافة المواد المعتمدة لهذا الصف بنجاح!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء التوليد: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAutoSeeding = false);
    }
  }

  Future<void> _deleteSubject(BuildContext context, String subjectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('حذف المادة'),
        content: const Text('هل أنت متأكد من حذف هذه المادة؟ سيتم حذف جميع الواجبات المرتبطة بها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final homeworkService = ref.read(homeworkServiceProvider);
      await homeworkService.deleteSubject(_selectedClassId!, subjectId);
      ref.invalidate(subjectsProvider(_selectedClassId!));
      await ref.read(subjectsProvider(_selectedClassId!).future);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المادة بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = AppConstants.sanitizeSchoolId(ref.watch(localStorageServiceProvider).getSchoolCode());
    final classesAsync = ref.watch(classesProvider(schoolId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hPadding = Responsive.getHorizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المواد الدراسية', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 12.0),
                child: classesAsync.when(
                  data: (classes) {
                    return DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'اختر الصف لعرض وتعديل مواده',
                        prefixIcon: const Icon(Icons.school_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      initialValue: _selectedClassId,
                      items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (val) {
                        final foundClass = classes.firstWhere((element) => element.id == val);
                        setState(() {
                          _selectedClassId = val;
                          _selectedClassName = foundClass.name;
                        });
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('خطأ: $e'),
                ),
              ),

              if (_selectedClassId != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPadding),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isAutoSeeding ? null : () => _autoSeedPrimarySubjects(context),
                          icon: _isAutoSeeding
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.auto_fix_high_rounded, color: AppColors.secondary),
                          label: const Text('توليد المواد الوزارية تلقائياً', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _addOrEditSubject(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('مادة جديدة', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Expanded(
                child: _selectedClassId != null
                    ? Consumer(
                        builder: (context, ref, child) {
                          final subjectsAsync = ref.watch(subjectsProvider(_selectedClassId!));

                          return subjectsAsync.when(
                            data: (subjects) {
                              if (subjects.isEmpty) {
                                return const Center(
                                  child: Text('لا توجد مواد لهذا الصف بعد. يمكنك توليدها أو إضافتها بالأعلى.'),
                                );
                              }

                              return ListView.builder(
                                padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 8),
                                itemCount: subjects.length,
                                itemBuilder: (context, index) {
                                  final subject = subjects[index];
                                  final gradient = SubjectVisualHelper.getSubjectGradient(subject.name, index);

                                  return Card(
                                    color: isDark ? AppColors.darkCard : Colors.white,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: gradient),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                                          boxShadow: [
                                            BoxShadow(
                                              color: gradient[0].withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          SubjectVisualHelper.getSubjectIcon(subject.name),
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                      title: Text(subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
                                            onPressed: () => _addOrEditSubject(context, existingSubject: subject),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                            onPressed: () => _deleteSubject(context, subject.id),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('خطأ: $e')),
                          );
                        },
                      )
                    : const Center(
                        child: Text('يرجى اختيار الصف الدراسي أولاً لعرض مواده', style: TextStyle(color: Colors.grey)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
