-- 1. Create the storage bucket 'school_assets' for homework and schedules
INSERT INTO storage.buckets (id, name, public)
VALUES ('school_assets', 'school_assets', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Allow public access to view images
DROP POLICY IF EXISTS "Public Access school_assets" ON storage.objects;
CREATE POLICY "Public Access school_assets"
ON storage.objects FOR SELECT
USING (bucket_id = 'school_assets');

-- 3. Allow uploads to school_assets
DROP POLICY IF EXISTS "Allow Uploads school_assets" ON storage.objects;
CREATE POLICY "Allow Uploads school_assets"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'school_assets');

-- 4. Allow updates and deletes to school_assets
DROP POLICY IF EXISTS "Allow Updates school_assets" ON storage.objects;
CREATE POLICY "Allow Updates school_assets"
ON storage.objects FOR UPDATE
USING (bucket_id = 'school_assets');

DROP POLICY IF EXISTS "Allow Deletes school_assets" ON storage.objects;
CREATE POLICY "Allow Deletes school_assets"
ON storage.objects FOR DELETE
USING (bucket_id = 'school_assets');
