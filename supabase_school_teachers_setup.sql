-- ==============================================================
-- إنشاء جدول تخصيص الأساتذة للمدارس (school_teachers)
-- شغّل هذا الملف مرة واحدة فقط في SQL Editor في لوحة تحكم Supabase
-- بعدها يمكنك إضافة وتعديل الأساتذة مباشرة من Table Editor كجدول إكسل!
-- ==============================================================

-- 1. إنشاء جدول المعلمين والمدارس
CREATE TABLE IF NOT EXISTS school_teachers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email text NOT NULL UNIQUE,
    school_code text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- 2. فتح صلاحية القراءة للتطبيق
ALTER TABLE school_teachers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow select for all school_teachers" ON school_teachers;
CREATE POLICY "Allow select for all school_teachers" ON school_teachers FOR SELECT USING (true);

-- 3. إضافة أستاذ متوسطة العناوين الحالي كبداية
INSERT INTO school_teachers (email, school_code)
VALUES ('aaef7736@gmail.com', 'ANAWEEN-1')
ON CONFLICT (email) DO UPDATE 
SET school_code = EXCLUDED.school_code;
