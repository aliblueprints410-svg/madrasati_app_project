-- ==============================================================
-- سكريبت إضافة مواد المرحلة الابتدائية (الصفوف 1 - 6) في Supabase
-- متوافق تماماً مع كود المدرسة 'SCH-1'
-- ==============================================================

-- 1. تنظيف المواد القديمة لصفوف مدرسة SCH-1 إن وجدت لتجنب التكرار
DELETE FROM subjects 
WHERE class_id IN (
    SELECT c.id FROM classes c 
    JOIN schools s ON c.school_id = s.id 
    WHERE s.school_code = 'SCH-1'
);

-- 2. مواد الصف الأول الابتدائي
INSERT INTO subjects (id, class_id, name)
SELECT gen_random_uuid(), c.id, s.name
FROM classes c
JOIN schools sch ON c.school_id = sch.id
CROSS JOIN (VALUES 
    ('التربية الاسلامية'),
    ('القراءة'),
    ('الرياضيات'),
    ('العلوم'),
    ('اللغة الانكليزية'),
    ('الاخلاقيه'),
    ('التربية الرياضية'),
    ('التربية الفنية')
) AS s(name)
WHERE sch.school_code = 'SCH-1' AND c.name LIKE '%الأول%';

-- 3. مواد الصف الثاني الابتدائي
INSERT INTO subjects (id, class_id, name)
SELECT gen_random_uuid(), c.id, s.name
FROM classes c
JOIN schools sch ON c.school_id = sch.id
CROSS JOIN (VALUES 
    ('التربية الاسلامية'),
    ('القراءة'),
    ('الرياضيات'),
    ('العلوم'),
    ('اللغة الانكليزية'),
    ('الاخلاقيه'),
    ('التربية الرياضية'),
    ('التربية الفنية')
) AS s(name)
WHERE sch.school_code = 'SCH-1' AND c.name LIKE '%الثاني%';

-- 4. مواد الصف الثالث الابتدائي
INSERT INTO subjects (id, class_id, name)
SELECT gen_random_uuid(), c.id, s.name
FROM classes c
JOIN schools sch ON c.school_id = sch.id
CROSS JOIN (VALUES 
    ('التربية الاسلامية'),
    ('القراءة'),
    ('الرياضيات'),
    ('العلوم'),
    ('اللغة الانكليزية'),
    ('الاخلاقيه'),
    ('التربية الرياضية'),
    ('التربية الفنية')
) AS s(name)
WHERE sch.school_code = 'SCH-1' AND c.name LIKE '%الثالث%';

-- 5. مواد الصف الرابع الابتدائي
INSERT INTO subjects (id, class_id, name)
SELECT gen_random_uuid(), c.id, s.name
FROM classes c
JOIN schools sch ON c.school_id = sch.id
CROSS JOIN (VALUES 
    ('التربية الاسلامية'),
    ('اللغة العربية'),
    ('الرياضيات'),
    ('العلوم'),
    ('اللغة الانكليزية'),
    ('الاجتماعيات'),
    ('التربية الرياضية'),
    ('التربية الفنية')
) AS s(name)
WHERE sch.school_code = 'SCH-1' AND c.name LIKE '%الرابع%';

-- 6. مواد الصف الخامس الابتدائي
INSERT INTO subjects (id, class_id, name)
SELECT gen_random_uuid(), c.id, s.name
FROM classes c
JOIN schools sch ON c.school_id = sch.id
CROSS JOIN (VALUES 
    ('التربية الاسلامية'),
    ('اللغة العربية'),
    ('الرياضيات'),
    ('العلوم'),
    ('اللغة الانكليزية'),
    ('الاجتماعيات'),
    ('التربية الرياضية'),
    ('التربية الفنية')
) AS s(name)
WHERE sch.school_code = 'SCH-1' AND c.name LIKE '%الخامس%';

-- 7. مواد الصف السادس الابتدائي
INSERT INTO subjects (id, class_id, name)
SELECT gen_random_uuid(), c.id, s.name
FROM classes c
JOIN schools sch ON c.school_id = sch.id
CROSS JOIN (VALUES 
    ('التربية الاسلامية'),
    ('اللغة العربية'),
    ('الرياضيات'),
    ('العلوم'),
    ('اللغة الانكليزية'),
    ('الاجتماعيات'),
    ('التربية الرياضية'),
    ('التربية الفنية')
) AS s(name)
WHERE sch.school_code = 'SCH-1' AND c.name LIKE '%السادس%';
