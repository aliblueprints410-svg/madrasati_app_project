import 'package:flutter/material.dart';

/// مساعد ذكي لتحديد الأيقونات والتدرجات اللونية والهوية البصرية لكل مادة دراسية
/// بناءً على المنهج العراقي والعربي بشكل دقيق واحترافي.
class SubjectVisualHelper {
  /// ترجع الأيقونة المناسبة لاسم المادة
  static IconData getSubjectIcon(String subjectName) {
    final s = subjectName.trim().toLowerCase();

    // 1. التربية الإسلامية والقرآن الكريم
    if (s.contains('اسلامية') ||
        s.contains('إسلامية') ||
        s.contains('اسلاميه') ||
        s.contains('إسلاميه') ||
        s.contains('دين') ||
        s.contains('قرآن') ||
        s.contains('قران') ||
        s.contains('عقيدة') ||
        s.contains('حديث') ||
        s.contains('فقه') ||
        s.contains('تفسير') ||
        s.contains('توحيد') ||
        s.contains('تلاوة')) {
      return Icons.mosque_rounded;
    }

    // 2. القراءة واللغة العربية والأدب
    if (s.contains('قراءة') ||
        s.contains('قراءه') ||
        s.contains('عربي') ||
        s.contains('عربية') ||
        s.contains('عربيه') ||
        s.contains('لغة عربية') ||
        s.contains('لغة') ||
        s.contains('لغتي') ||
        s.contains('قواعد') ||
        s.contains('إملاء') ||
        s.contains('املاء') ||
        s.contains('نصوص') ||
        s.contains('تعبير') ||
        s.contains('بلاغة') ||
        s.contains('أدب') ||
        s.contains('ادب')) {
      return Icons.auto_stories_rounded;
    }

    // 3. الرياضيات والجبر والهندسة
    if (s.contains('رياضيات') ||
        s.contains('حساب') ||
        s.contains('جبر') ||
        s.contains('هندسة') ||
        s.contains('هندسه') ||
        s.contains('تفاضل') ||
        s.contains('تكامل') ||
        s.contains('math')) {
      return Icons.calculate_rounded;
    }

    // 4. الأحياء
    if (s.contains('أحياء') || s.contains('احياء') || s.contains('bio')) {
      return Icons.biotech_rounded;
    }

    // 5. الفيزياء
    if (s.contains('فيزياء') || s.contains('physics')) {
      return Icons.bolt_rounded;
    }

    // 6. الكيمياء
    if (s.contains('كيمياء') || s.contains('chemistry')) {
      return Icons.science_rounded;
    }

    // 7. العلوم العامة والبيئة
    if (s.contains('علوم') ||
        s.contains('علم') ||
        s.contains('طبيعيات') ||
        s.contains('science') ||
        s.contains('مختبر')) {
      return Icons.science_rounded;
    }

    // 5. اللغة الإنجليزية
    if (s.contains('انكليزي') ||
        s.contains('إنكليزي') ||
        s.contains('انجليزي') ||
        s.contains('إنجليزي') ||
        s.contains('إنجليزية') ||
        s.contains('انجليزية') ||
        s.contains('english') ||
        s.contains('en')) {
      return Icons.translate_rounded;
    }

    // 6. الاجتماعيات والتاريخ والجغرافيا والوطنية
    if (s.contains('اجتماعيات') ||
        s.contains('تاريخ') ||
        s.contains('جغرافيا') ||
        s.contains('جغرافية') ||
        s.contains('وطنية') ||
        s.contains('مواطنة') ||
        s.contains('اجتماعية') ||
        s.contains('social')) {
      return Icons.public_rounded;
    }

    // 7. التربية الأخلاقية والقيم
    if (s.contains('أخلاق') ||
        s.contains('اخلاق') ||
        s.contains('أخلاقية') ||
        s.contains('اخلاقيه') ||
        s.contains('سلوك') ||
        s.contains('قيم')) {
      return Icons.favorite_rounded;
    }

    // 8. التربية الفنية والرسم
    if (s.contains('فنية') ||
        s.contains('فنيه') ||
        s.contains('رسم') ||
        s.contains('أشغال') ||
        s.contains('تشكيلية') ||
        s.contains('art')) {
      return Icons.palette_rounded;
    }

    // 9. التربية الرياضية والبدنية
    if (s.contains('رياضة') ||
        s.contains('رياضه') ||
        s.contains('بدنية') ||
        s.contains('بدنيه') ||
        s.contains('العاب') ||
        s.contains('ألعاب') ||
        s.contains('sport') ||
        s.contains('pe')) {
      return Icons.sports_soccer_rounded;
    }

    // 10. الحاسوب والتكنولوجيا والبرمجة
    if (s.contains('حاسوب') ||
        s.contains('كمبيوتر') ||
        s.contains('تقنية') ||
        s.contains('تكنولوجيا') ||
        s.contains('برمجة') ||
        s.contains('رقمي') ||
        s.contains('computer') ||
        s.contains('it')) {
      return Icons.laptop_chromebook_rounded;
    }

    // 11. الموسيقى والنشيد
    if (s.contains('موسيقى') || s.contains('نشيد') || s.contains('اناشيد')) {
      return Icons.music_note_rounded;
    }

    // 12. المهارات الحياتية أو المهنية
    if (s.contains('مهارات') || s.contains('مهني')) {
      return Icons.handyman_rounded;
    }

    return Icons.school_rounded;
  }

  /// ترجع تدرجاً لونياً جذاباً ومخصصاً لطبيعة كل مادة
  static List<Color> getSubjectGradient(String subjectName, [int fallbackIndex = 0]) {
    final s = subjectName.trim().toLowerCase();

    // 1. التربية الإسلامية: أخضر زمردي إسلامي وقور
    if (s.contains('اسلامية') ||
        s.contains('إسلامية') ||
        s.contains('دين') ||
        s.contains('قرآن') ||
        s.contains('قران')) {
      return const [Color(0xFF059669), Color(0xFF047857)]; // Emerald
    }

    // 2. القراءة واللغة العربية: أزرق سماوي مشرق
    if (s.contains('قراءة') ||
        s.contains('قراءه') ||
        s.contains('عربي') ||
        s.contains('لغة')) {
      return const [Color(0xFF0284C7), Color(0xFF0369A1)]; // Sky Blue
    }

    // 3. الرياضيات: عنبري برتقالي ذكي ومحفّز
    if (s.contains('رياضيات') || s.contains('حساب') || s.contains('math')) {
      return const [Color(0xFFEA580C), Color(0xFFC2410C)]; // Orange/Amber
    }

    // 4. الأحياء: أخضر طبيعي حيوي
    if (s.contains('أحياء') || s.contains('احياء') || s.contains('bio')) {
      return const [Color(0xFF16A34A), Color(0xFF15803D)]; // Forest Green
    }

    // 5. الفيزياء: كحلي نيلي كهربائي حديث
    if (s.contains('فيزياء') || s.contains('physics')) {
      return const [Color(0xFF4F46E5), Color(0xFF3730A3)]; // Indigo
    }

    // 6. الكيمياء: بنفسجي مخبري متألق
    if (s.contains('كيمياء') || s.contains('chemistry')) {
      return const [Color(0xFF8B5CF6), Color(0xFF6D28D9)]; // Violet
    }

    // 7. العلوم العامة: أرجواني عصري
    if (s.contains('علوم') || s.contains('science')) {
      return const [Color(0xFF9333EA), Color(0xFF7E22CE)]; // Purple
    }

    // 5. الإنجليزية: وردي مرجاني نشيط
    if (s.contains('انكليزي') ||
        s.contains('إنكليزي') ||
        s.contains('انجليزي') ||
        s.contains('english')) {
      return const [Color(0xFFE11D48), Color(0xFFBE123C)]; // Rose
    }

    // 6. الاجتماعيات: فيروزي بحري غني
    if (s.contains('اجتماعيات') ||
        s.contains('تاريخ') ||
        s.contains('جغرافيا') ||
        s.contains('وطنية')) {
      return const [Color(0xFF0891B2), Color(0xFF0E7490)]; // Teal
    }

    // 7. الأخلاقية: فوشي وردي لطيف
    if (s.contains('أخلاق') || s.contains('اخلاق')) {
      return const [Color(0xFFDB2777), Color(0xFF9D174D)]; // Pink
    }

    // 8. الفنية: تدرج كهرماني مشرق
    if (s.contains('فنية') || s.contains('فنيه') || s.contains('رسم')) {
      return const [Color(0xFFF59E0B), Color(0xFFD97706)]; // Amber
    }

    // 9. الرياضة: نعناعي حيوي
    if (s.contains('رياضة') || s.contains('بدنية')) {
      return const [Color(0xFF10B981), Color(0xFF059669)]; // Mint
    }

    // 10. الحاسوب: أزرق نيلي تكنولوجي
    if (s.contains('حاسوب') || s.contains('كمبيوتر') || s.contains('تقنية')) {
      return const [Color(0xFF4F46E5), Color(0xFF3730A3)]; // Indigo
    }

    // في حال عدم التعرف، نستخدم دورة الألوان الأساسية
    final defaultPalette = [
      const [Color(0xFF6366F1), Color(0xFF4338CA)],
      const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
      const [Color(0xFF10B981), Color(0xFF059669)],
      const [Color(0xFFF59E0B), Color(0xFFD97706)],
      const [Color(0xFFEC4899), Color(0xFFDB2777)],
      const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      const [Color(0xFF14B8A6), Color(0xFF0F766E)],
      const [Color(0xFFF43F5E), Color(0xFFE11D48)],
    ];
    return defaultPalette[fallbackIndex % defaultPalette.length];
  }

  /// ويدجت أيقونة المادة الفخمة ثلاثية الأبعاد والمريحة بصرياً
  static Widget buildSubjectIconBadge({
    required String subjectName,
    double size = 58,
    double iconSize = 28,
    double borderRadius = 18,
    int fallbackIndex = 0,
    bool showGlow = true,
  }) {
    final icon = getSubjectIcon(subjectName);
    final gradient = getSubjectGradient(subjectName, fallbackIndex);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1.4,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: gradient[0].withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}
