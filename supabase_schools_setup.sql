-- ==============================================================
-- إعداد وترتيب نظام المدارس (ابتدائية أو متوسطة) ومنع تكرار المواد
-- شغّل هذا الكود في SQL Editor في Supabase واضغط RUN
-- ==============================================================

-- 1. إضافة عمود المرحلة (stage) لجدول المدارس
ALTER TABLE schools ADD COLUMN IF NOT EXISTS stage text DEFAULT 'primary';

-- تحديد مرحلة كل مدرسة حالية
UPDATE schools SET stage = 'middle' WHERE school_code = 'ANAWEEN-1' OR name LIKE '%متوسط%';
UPDATE schools SET stage = 'primary' WHERE stage IS NULL OR school_code LIKE 'SCH-%' OR name LIKE '%ابتدائ%';

-- 2. تنظيف المواد المكررة في جدول المواد لتبقى كل مادة مرة واحدة فقط
DELETE FROM subjects 
WHERE id NOT IN (
    SELECT MIN(id::text)::uuid 
    FROM subjects 
    GROUP BY class_id, TRIM(name)
);

-- 3. وضع قيد فريد يمنع تكرار اسم المادة في نفس الصف للأبد
ALTER TABLE subjects DROP CONSTRAINT IF EXISTS unique_subject_per_class;
ALTER TABLE subjects ADD CONSTRAINT unique_subject_per_class UNIQUE (class_id, name);
