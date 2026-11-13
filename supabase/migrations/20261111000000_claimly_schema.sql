-- =============================================================================
-- Claimly Database Schema & Security Migration
-- Version: 20261111000000
-- Description: Core tables, enums, triggers, RLS policies, storage buckets, and realtime
-- =============================================================================

-- Ensure necessary extensions are enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================================
-- 1. ENUMS & CUSTOM TYPES
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE public.user_role AS ENUM ('customer', 'admin');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'claim_type') THEN
    CREATE TYPE public.claim_type AS ENUM ('warranty', 'refund', 'replacement');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'claim_status') THEN
    CREATE TYPE public.claim_status AS ENUM (
      'draft',
      'submitted',
      'under_review',
      'approved',
      'rejected',
      'completed'
    );
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type') THEN
    CREATE TYPE public.notification_type AS ENUM (
      'warranty_expiry',
      'claim_update',
      'system'
    );
  END IF;
END
$$;

-- =============================================================================
-- 2. PRELIMINARY HELPER FUNCTIONS
-- =============================================================================

-- Immutable calculation of warranty expiry date
CREATE OR REPLACE FUNCTION public.calculate_warranty_expiry(p_purchase_date date, p_months integer)
RETURNS date
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (p_purchase_date + (p_months * INTERVAL '1 month'))::date;
$$;

COMMENT ON FUNCTION public.calculate_warranty_expiry IS 'Deterministically calculates warranty expiration date from purchase date and months';

-- General updated_at timestamp updater
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- =============================================================================
-- 3. RELATIONAL TABLES
-- =============================================================================

-- 1. Profiles Table (extends auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.user_role NOT NULL DEFAULT 'customer',
  full_name text,
  avatar_url text,
  phone_number text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Secure admin verification function
-- Defined with SECURITY DEFINER and fixed search_path to prevent infinite RLS recursion and search path hijacking
CREATE OR REPLACE FUNCTION public.is_admin(check_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = COALESCE(check_user_id, auth.uid()) AND role = 'admin'
  );
$$;

COMMENT ON FUNCTION public.is_admin IS 'Verifies whether the given user (or caller) possesses the admin role';

-- 2. Products Table
CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name text NOT NULL,
  category text NOT NULL,
  brand text,
  model_number text,
  serial_number text,
  purchase_date date NOT NULL,
  warranty_period_months integer NOT NULL CHECK (warranty_period_months >= 0),
  warranty_expiry_date date NOT NULL,
  receipt_url text,
  image_url text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 3. Claims Table
CREATE TABLE IF NOT EXISTS public.claims (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_number text UNIQUE NOT NULL,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  type public.claim_type NOT NULL DEFAULT 'warranty',
  status public.claim_status NOT NULL DEFAULT 'draft',
  title text NOT NULL,
  description text NOT NULL,
  issue_category text,
  incident_date date,
  priority integer NOT NULL DEFAULT 0,
  admin_notes text,
  resolution_notes text,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- 4. Claim Attachments Table
CREATE TABLE IF NOT EXISTS public.claim_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid NOT NULL REFERENCES public.claims(id) ON DELETE CASCADE,
  file_url text NOT NULL,
  file_name text NOT NULL,
  file_type text,
  file_size integer,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 5. Claim Timeline Table
CREATE TABLE IF NOT EXISTS public.claim_timeline (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  claim_id uuid NOT NULL REFERENCES public.claims(id) ON DELETE CASCADE,
  from_status public.claim_status,
  to_status public.claim_status NOT NULL,
  changed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- 6. Notifications Table
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  claim_id uuid REFERENCES public.claims(id) ON DELETE CASCADE,
  type public.notification_type NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- 4. PERFORMANCE & QUERY INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_products_user_id ON public.products(user_id);
CREATE INDEX IF NOT EXISTS idx_products_warranty_expiry ON public.products(warranty_expiry_date);
CREATE INDEX IF NOT EXISTS idx_claims_user_id ON public.claims(user_id);
CREATE INDEX IF NOT EXISTS idx_claims_product_id ON public.claims(product_id);
CREATE INDEX IF NOT EXISTS idx_claims_status ON public.claims(status);
CREATE INDEX IF NOT EXISTS idx_claims_created_at ON public.claims(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_claim_attachments_claim_id ON public.claim_attachments(claim_id);
CREATE INDEX IF NOT EXISTS idx_claim_timeline_claim_id_created ON public.claim_timeline(claim_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread ON public.notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_claim_id ON public.notifications(claim_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);

-- =============================================================================
-- 5. AUTOMATED TRIGGERS & LOGIC
-- =============================================================================

-- A. Timestamp triggers (updated_at)
DROP TRIGGER IF EXISTS set_profiles_updated_at ON public.profiles;
CREATE TRIGGER set_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_products_updated_at ON public.products;
CREATE TRIGGER set_products_updated_at
BEFORE UPDATE ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

DROP TRIGGER IF EXISTS set_claims_updated_at ON public.claims;
CREATE TRIGGER set_claims_updated_at
BEFORE UPDATE ON public.claims
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- B. Product Warranty Expiry Trigger
CREATE OR REPLACE FUNCTION public.handle_product_warranty_expiry()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.warranty_expiry_date := public.calculate_warranty_expiry(NEW.purchase_date, NEW.warranty_period_months);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_product_warranty_expiry ON public.products;
CREATE TRIGGER set_product_warranty_expiry
BEFORE INSERT OR UPDATE OF purchase_date, warranty_period_months, warranty_expiry_date ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.handle_product_warranty_expiry();

-- C. Claim Number Generation Trigger
CREATE OR REPLACE FUNCTION public.handle_generate_claim_number()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF (auth.uid() IS NOT NULL AND NOT public.is_admin(auth.uid())) OR NEW.claim_number IS NULL OR NEW.claim_number = '' THEN
      NEW.claim_number := 'CLM-' || to_char(now(), 'YYYYMMDD') || '-' || upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    NEW.claim_number := OLD.claim_number;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS generate_claim_number ON public.claims;
CREATE TRIGGER generate_claim_number
BEFORE INSERT OR UPDATE ON public.claims
FOR EACH ROW
EXECUTE FUNCTION public.handle_generate_claim_number();

-- D. Claim Resolution Date Trigger
CREATE OR REPLACE FUNCTION public.handle_claim_resolved_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status IN ('approved', 'rejected', 'completed') AND (OLD.status NOT IN ('approved', 'rejected', 'completed') OR OLD.status IS NULL) THEN
    IF NEW.resolved_at IS NULL THEN
      NEW.resolved_at := now();
    END IF;
  ELSIF NEW.status IN ('draft', 'submitted', 'under_review') AND OLD.status IN ('approved', 'rejected', 'completed') THEN
    NEW.resolved_at := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_claim_resolved_at ON public.claims;
CREATE TRIGGER set_claim_resolved_at
BEFORE UPDATE OF status ON public.claims
FOR EACH ROW
EXECUTE FUNCTION public.handle_claim_resolved_at();

-- E. Claim Status Timeline Logging Trigger
CREATE OR REPLACE FUNCTION public.handle_claim_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.claim_timeline (
      claim_id,
      from_status,
      to_status,
      changed_by,
      notes,
      created_at
    ) VALUES (
      NEW.id,
      NULL,
      NEW.status,
      auth.uid(),
      'Claim created with status ' || NEW.status::text,
      now()
    );
  ELSIF TG_OP = 'UPDATE' AND (OLD.status IS DISTINCT FROM NEW.status) THEN
    INSERT INTO public.claim_timeline (
      claim_id,
      from_status,
      to_status,
      changed_by,
      notes,
      created_at
    ) VALUES (
      NEW.id,
      OLD.status,
      NEW.status,
      auth.uid(),
      COALESCE(NEW.admin_notes, 'Status transitioned from ' || OLD.status::text || ' to ' || NEW.status::text),
      now()
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS log_claim_creation ON public.claims;
CREATE TRIGGER log_claim_creation
AFTER INSERT ON public.claims
FOR EACH ROW
EXECUTE FUNCTION public.handle_claim_status_change();

DROP TRIGGER IF EXISTS log_claim_status_change ON public.claims;
CREATE TRIGGER log_claim_status_change
AFTER UPDATE OF status ON public.claims
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION public.handle_claim_status_change();

-- F. Notify Claim Update Trigger
CREATE OR REPLACE FUNCTION public.handle_notify_claim_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notifications (
    user_id,
    claim_id,
    type,
    title,
    message,
    is_read,
    metadata,
    created_at
  ) VALUES (
    NEW.user_id,
    NEW.id,
    'claim_update',
    'Claim Status Updated',
    'Your claim ' || NEW.claim_number || ' status is now ' || replace(NEW.status::text, '_', ' ') || '.',
    false,
    jsonb_build_object(
      'claim_id', NEW.id,
      'claim_number', NEW.claim_number,
      'from_status', OLD.status,
      'to_status', NEW.status,
      'updated_at', now()
    ),
    now()
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_claim_update ON public.claims;
CREATE TRIGGER notify_claim_update
AFTER UPDATE OF status ON public.claims
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION public.handle_notify_claim_update();

-- G. Protect User Role (Anti-Escalation) Trigger
CREATE OR REPLACE FUNCTION public.handle_protect_user_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.role <> 'customer' AND (auth.uid() IS NULL OR NOT public.is_admin(auth.uid())) THEN
      RAISE EXCEPTION 'Unauthorized: Only administrators can assign privileged roles';
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF auth.uid() IS NOT NULL AND NOT public.is_admin(auth.uid()) THEN
      RAISE EXCEPTION 'Unauthorized: Only administrators can modify user roles';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_user_role ON public.profiles;
CREATE TRIGGER protect_user_role
BEFORE INSERT OR UPDATE OF role ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.handle_protect_user_role();

-- H. New User Profile Auto-Population Trigger (from auth.users)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    role,
    full_name,
    avatar_url,
    phone_number,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    'customer',
    COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name',
      split_part(NEW.email, '@', 1)
    ),
    COALESCE(
      NEW.raw_user_meta_data->>'avatar_url',
      NEW.raw_user_meta_data->>'picture',
      NULL
    ),
    COALESCE(
      NEW.phone,
      NEW.raw_user_meta_data->>'phone_number',
      NULL
    ),
    now(),
    now()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_user();

-- I. Protect Claim Administrative Fields Trigger
CREATE OR REPLACE FUNCTION public.handle_protect_claim_admin_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin(auth.uid()) THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.priority <> 0 OR
         NEW.admin_notes IS NOT NULL OR
         NEW.resolution_notes IS NOT NULL OR
         NEW.resolved_at IS NOT NULL OR
         NEW.status NOT IN ('draft', 'submitted') THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators can set administrative claim fields or non-draft status on creation';
      END IF;
    ELSIF TG_OP = 'UPDATE' THEN
      IF NEW.priority IS DISTINCT FROM OLD.priority OR
         NEW.admin_notes IS DISTINCT FROM OLD.admin_notes OR
         NEW.resolution_notes IS DISTINCT FROM OLD.resolution_notes OR
         NEW.resolved_at IS DISTINCT FROM OLD.resolved_at THEN
        RAISE EXCEPTION 'Unauthorized: Only administrators can modify administrative claim fields';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_claim_admin_fields ON public.claims;
CREATE TRIGGER protect_claim_admin_fields
BEFORE INSERT OR UPDATE ON public.claims
FOR EACH ROW
EXECUTE FUNCTION public.handle_protect_claim_admin_fields();

-- =============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================================================

-- Enable RLS across all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.claim_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.claim_timeline ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Profiles Policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "profiles_select_own_or_admin" ON public.profiles;
CREATE POLICY "profiles_select_own_or_admin"
ON public.profiles FOR SELECT
TO authenticated
USING (auth.uid() = id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "profiles_insert_own_or_admin" ON public.profiles;
CREATE POLICY "profiles_insert_own_or_admin"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (
  (auth.uid() = id AND role = 'customer')
  OR public.is_admin(auth.uid())
);

DROP POLICY IF EXISTS "profiles_update_own_or_admin" ON public.profiles;
CREATE POLICY "profiles_update_own_or_admin"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id OR public.is_admin(auth.uid()))
WITH CHECK (auth.uid() = id OR public.is_admin(auth.uid()));

-- -----------------------------------------------------------------------------
-- Products Policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "products_select_own_or_admin" ON public.products;
CREATE POLICY "products_select_own_or_admin"
ON public.products FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "products_insert_own" ON public.products;
CREATE POLICY "products_insert_own"
ON public.products FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "products_update_own_or_admin" ON public.products;
CREATE POLICY "products_update_own_or_admin"
ON public.products FOR UPDATE
TO authenticated
USING (auth.uid() = user_id OR public.is_admin(auth.uid()))
WITH CHECK (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "products_delete_own_or_admin" ON public.products;
CREATE POLICY "products_delete_own_or_admin"
ON public.products FOR DELETE
TO authenticated
USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

-- -----------------------------------------------------------------------------
-- Claims Policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "claims_select_own_or_admin" ON public.claims;
CREATE POLICY "claims_select_own_or_admin"
ON public.claims FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "claims_insert_own" ON public.claims;
CREATE POLICY "claims_insert_own"
ON public.claims FOR INSERT
TO authenticated
WITH CHECK (
  (
    auth.uid() = user_id
    AND status IN ('draft', 'submitted')
    AND admin_notes IS NULL
    AND resolution_notes IS NULL
    AND resolved_at IS NULL
    AND priority = 0
    AND EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = claims.product_id
        AND p.user_id = auth.uid()
    )
  )
  OR public.is_admin(auth.uid())
);

DROP POLICY IF EXISTS "claims_update_draft_or_admin" ON public.claims;
CREATE POLICY "claims_update_draft_or_admin"
ON public.claims FOR UPDATE
TO authenticated
USING (
  (auth.uid() = user_id AND status = 'draft')
  OR public.is_admin(auth.uid())
)
WITH CHECK (
  (
    auth.uid() = user_id
    AND status IN ('draft', 'submitted')
    AND admin_notes IS NULL
    AND resolution_notes IS NULL
    AND resolved_at IS NULL
    AND priority = 0
    AND EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = claims.product_id
        AND p.user_id = auth.uid()
    )
  )
  OR public.is_admin(auth.uid())
);

DROP POLICY IF EXISTS "claims_delete_draft_or_admin" ON public.claims;
CREATE POLICY "claims_delete_draft_or_admin"
ON public.claims FOR DELETE
TO authenticated
USING (
  (auth.uid() = user_id AND status = 'draft')
  OR public.is_admin(auth.uid())
);

-- -----------------------------------------------------------------------------
-- Claim Attachments Policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "attachments_select_owner_or_admin" ON public.claim_attachments;
CREATE POLICY "attachments_select_owner_or_admin"
ON public.claim_attachments FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.claims c
    WHERE c.id = claim_attachments.claim_id
      AND (c.user_id = auth.uid() OR public.is_admin(auth.uid()))
  )
);

DROP POLICY IF EXISTS "attachments_insert_owner_or_admin" ON public.claim_attachments;
CREATE POLICY "attachments_insert_owner_or_admin"
ON public.claim_attachments FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.claims c
    WHERE c.id = claim_attachments.claim_id
      AND (c.user_id = auth.uid() OR public.is_admin(auth.uid()))
  )
);

DROP POLICY IF EXISTS "attachments_update_draft_or_admin" ON public.claim_attachments;
CREATE POLICY "attachments_update_draft_or_admin"
ON public.claim_attachments FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.claims c
    WHERE c.id = claim_attachments.claim_id
      AND ((c.user_id = auth.uid() AND c.status = 'draft') OR public.is_admin(auth.uid()))
  )
);

DROP POLICY IF EXISTS "attachments_delete_draft_or_admin" ON public.claim_attachments;
CREATE POLICY "attachments_delete_draft_or_admin"
ON public.claim_attachments FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.claims c
    WHERE c.id = claim_attachments.claim_id
      AND ((c.user_id = auth.uid() AND c.status = 'draft') OR public.is_admin(auth.uid()))
  )
);

-- -----------------------------------------------------------------------------
-- Claim Timeline Policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "timeline_select_owner_or_admin" ON public.claim_timeline;
CREATE POLICY "timeline_select_owner_or_admin"
ON public.claim_timeline FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.claims c
    WHERE c.id = claim_timeline.claim_id
      AND (c.user_id = auth.uid() OR public.is_admin(auth.uid()))
  )
);

DROP POLICY IF EXISTS "timeline_insert_owner_or_admin" ON public.claim_timeline;
DROP POLICY IF EXISTS "timeline_insert_admin_only" ON public.claim_timeline;
CREATE POLICY "timeline_insert_admin_only"
ON public.claim_timeline FOR INSERT
TO authenticated
WITH CHECK (public.is_admin(auth.uid()));

-- -----------------------------------------------------------------------------
-- Notifications Policies
-- -----------------------------------------------------------------------------
DROP POLICY IF EXISTS "notifications_select_own_or_admin" ON public.notifications;
CREATE POLICY "notifications_select_own_or_admin"
ON public.notifications FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "notifications_update_own_or_admin" ON public.notifications;
CREATE POLICY "notifications_update_own_or_admin"
ON public.notifications FOR UPDATE
TO authenticated
USING (auth.uid() = user_id OR public.is_admin(auth.uid()))
WITH CHECK (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "notifications_delete_own_or_admin" ON public.notifications;
CREATE POLICY "notifications_delete_own_or_admin"
ON public.notifications FOR DELETE
TO authenticated
USING (auth.uid() = user_id OR public.is_admin(auth.uid()));

DROP POLICY IF EXISTS "notifications_insert_admin" ON public.notifications;
CREATE POLICY "notifications_insert_admin"
ON public.notifications FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id OR public.is_admin(auth.uid()));

-- =============================================================================
-- 7. STORAGE BUCKETS & STORAGE RLS POLICIES
-- =============================================================================

-- Ensure buckets exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('receipts', 'receipts', false, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']),
  ('product-images', 'product-images', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('claim-attachments', 'claim-attachments', false, 20971520, ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf', 'video/mp4']),
  ('avatars', 'avatars', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage Objects Policies

-- 1. Receipts (Private, scoped to user folder or admin)
DROP POLICY IF EXISTS "receipts_select_policy" ON storage.objects;
CREATE POLICY "receipts_select_policy"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'receipts'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

DROP POLICY IF EXISTS "receipts_insert_policy" ON storage.objects;
CREATE POLICY "receipts_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'receipts'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

DROP POLICY IF EXISTS "receipts_update_policy" ON storage.objects;
CREATE POLICY "receipts_update_policy"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'receipts'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

DROP POLICY IF EXISTS "receipts_delete_policy" ON storage.objects;
CREATE POLICY "receipts_delete_policy"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'receipts'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

-- 2. Product Images (Public read, authenticated upload to user folder)
DROP POLICY IF EXISTS "product_images_select_policy" ON storage.objects;
CREATE POLICY "product_images_select_policy"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "product_images_insert_policy" ON storage.objects;
CREATE POLICY "product_images_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'product-images'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

DROP POLICY IF EXISTS "product_images_update_policy" ON storage.objects;
CREATE POLICY "product_images_update_policy"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'product-images'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

DROP POLICY IF EXISTS "product_images_delete_policy" ON storage.objects;
CREATE POLICY "product_images_delete_policy"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'product-images'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

-- 3. Claim Attachments (Private, scoped to user folder or admin)
DROP POLICY IF EXISTS "claim_attachments_select_policy" ON storage.objects;
CREATE POLICY "claim_attachments_select_policy"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'claim-attachments'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

DROP POLICY IF EXISTS "claim_attachments_insert_policy" ON storage.objects;
CREATE POLICY "claim_attachments_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'claim-attachments'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

DROP POLICY IF EXISTS "claim_attachments_update_policy" ON storage.objects;
CREATE POLICY "claim_attachments_update_policy"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'claim-attachments'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

DROP POLICY IF EXISTS "claim_attachments_delete_policy" ON storage.objects;
CREATE POLICY "claim_attachments_delete_policy"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'claim-attachments'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

-- 4. Avatars (Public read, authenticated upload to user folder)
DROP POLICY IF EXISTS "avatars_select_policy" ON storage.objects;
CREATE POLICY "avatars_select_policy"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_insert_policy" ON storage.objects;
CREATE POLICY "avatars_insert_policy"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

DROP POLICY IF EXISTS "avatars_update_policy" ON storage.objects;
CREATE POLICY "avatars_update_policy"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

DROP POLICY IF EXISTS "avatars_delete_policy" ON storage.objects;
CREATE POLICY "avatars_delete_policy"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'avatars'
  AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin(auth.uid()))
);

-- =============================================================================
-- 8. REALTIME CONFIGURATION & REPLICA IDENTITY
-- =============================================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'claims'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.claims;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'claim_timeline'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.claim_timeline;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END
$$;

ALTER TABLE public.claims REPLICA IDENTITY FULL;
ALTER TABLE public.claim_timeline REPLICA IDENTITY FULL;
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- =============================================================================
-- 9. PERMISSIONS AND GRANTS
-- =============================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.calculate_warranty_expiry(date, integer) TO anon, authenticated, service_role;
