-- ==============================================================================
-- حل شامل لجميع صلاحيات الجداول ومساحة التخزين في تطبيق مدرستي
-- انسخ هذا الكود بالكامل والصقه في SQL Editor في لوحة تحكم Supabase واضغط RUN
-- ==============================================================================

-- 1. إضافة عمود deadline لجدول الواجبات إذا لم يكن موجوداً
ALTER TABLE IF EXISTS homework ADD COLUMN IF NOT EXISTS deadline timestamptz;

-- 2. فتح صلاحيات جدول التعليقات (announcement_comments) للطلاب والمعلمين
ALTER TABLE IF EXISTS announcement_comments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select for all announcement_comments" ON announcement_comments;
CREATE POLICY "Allow select for all announcement_comments" ON announcement_comments FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert for all announcement_comments" ON announcement_comments;
CREATE POLICY "Allow insert for all announcement_comments" ON announcement_comments FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow delete for all announcement_comments" ON announcement_comments;
CREATE POLICY "Allow delete for all announcement_comments" ON announcement_comments FOR DELETE USING (true);

-- 3. فتح صلاحيات جدول المواد الدراسية (subjects) للإضافة والتعديل والحذف
ALTER TABLE IF EXISTS subjects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select for all subjects" ON subjects;
CREATE POLICY "Allow select for all subjects" ON subjects FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert for all subjects" ON subjects;
CREATE POLICY "Allow insert for all subjects" ON subjects FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update for all subjects" ON subjects;
CREATE POLICY "Allow update for all subjects" ON subjects FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Allow delete for all subjects" ON subjects;
CREATE POLICY "Allow delete for all subjects" ON subjects FOR DELETE USING (true);

-- 4. فتح صلاحيات جدول الصفوف (classes) لتحديث جدول الحصص
ALTER TABLE IF EXISTS classes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select for all classes" ON classes;
CREATE POLICY "Allow select for all classes" ON classes FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow update for all classes" ON classes;
CREATE POLICY "Allow update for all classes" ON classes FOR UPDATE USING (true);

-- 5. فتح صلاحيات جدول الواجبات والتحاضير (homework)
ALTER TABLE IF EXISTS homework ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select for all homework" ON homework;
CREATE POLICY "Allow select for all homework" ON homework FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert for all homework" ON homework;
CREATE POLICY "Allow insert for all homework" ON homework FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow update for all homework" ON homework;
CREATE POLICY "Allow update for all homework" ON homework FOR UPDATE USING (true);

DROP POLICY IF EXISTS "Allow delete for all homework" ON homework;
CREATE POLICY "Allow delete for all homework" ON homework FOR DELETE USING (true);

-- 6. إنشاء مساحة تخزين الصور (school_assets) لرفع صور الواجبات وجداول الحصص
INSERT INTO storage.buckets (id, name, public)
VALUES ('school_assets', 'school_assets', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 7. فتح صلاحيات تخزين الصور للجميع (عرض + رفع)
DROP POLICY IF EXISTS "Public View school_assets" ON storage.objects;
CREATE POLICY "Public View school_assets" ON storage.objects FOR SELECT USING (bucket_id = 'school_assets');

DROP POLICY IF EXISTS "Allow Upload school_assets" ON storage.objects;
CREATE POLICY "Allow Upload school_assets" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'school_assets');

DROP POLICY IF EXISTS "Allow Update school_assets" ON storage.objects;
CREATE POLICY "Allow Update school_assets" ON storage.objects FOR UPDATE USING (bucket_id = 'school_assets');

DROP POLICY IF EXISTS "Allow Delete school_assets" ON storage.objects;
CREATE POLICY "Allow Delete school_assets" ON storage.objects FOR DELETE USING (bucket_id = 'school_assets');
