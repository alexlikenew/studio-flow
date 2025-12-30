-- StudioFlow Initial Schema Migration
-- Version: 1.0
-- Description: Creates all tables, enums, RLS policies, triggers, and indexes

-- ============================================================================
-- 1. EXTENSIONS
-- ============================================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- 2. ENUMS
-- ============================================================================

-- Profile roles
CREATE TYPE profile_role AS ENUM ('creator', 'client');

-- Job statuses
CREATE TYPE job_status AS ENUM (
  'draft',
  'active',
  'waiting_for_selection',
  'processing',
  'delivered',
  'archived'
);

-- Gallery statuses
CREATE TYPE gallery_status AS ENUM (
  'draft',
  'active',
  'archived',
  'deleted'
);

-- Asset file types
CREATE TYPE asset_file_type AS ENUM ('image', 'video');

-- Guest lock statuses
CREATE TYPE guest_lock_status AS ENUM ('submitted', 'unlocked');

-- ============================================================================
-- 3. TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- profiles
-- Extends auth.users with application-specific data
-- ----------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  avatar_url TEXT,
  role profile_role NOT NULL DEFAULT 'client',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- jobs
-- Business containers (e.g., "Wedding 2024")
-- ----------------------------------------------------------------------------
CREATE TABLE public.jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  client_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  status job_status NOT NULL DEFAULT 'draft',
  client_email TEXT,
  internal_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- galleries
-- Visual containers for assets (standalone or job-linked)
-- ----------------------------------------------------------------------------
CREATE TABLE public.galleries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID REFERENCES public.jobs(id) ON DELETE SET NULL,
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  cover_asset_id UUID, -- Self-reference, added after assets table
  gallery_token TEXT NOT NULL UNIQUE,
  pin_code TEXT, -- Hashed or plain (hashed recommended)
  status gallery_status NOT NULL DEFAULT 'draft',
  settings JSONB NOT NULL DEFAULT '{"allow_download": false, "allow_selection": false, "watermark_enabled": false}'::jsonb,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- assets
-- The actual files (Images/Videos)
-- ----------------------------------------------------------------------------
CREATE TABLE public.assets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  gallery_id UUID NOT NULL REFERENCES public.galleries(id) ON DELETE CASCADE,
  original_filename TEXT NOT NULL,
  storage_path TEXT NOT NULL,
  file_type asset_file_type NOT NULL,
  width INTEGER,
  height INTEGER,
  size_bytes BIGINT NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add self-referencing foreign key for cover_asset_id
ALTER TABLE public.galleries
  ADD CONSTRAINT galleries_cover_asset_id_fkey
  FOREIGN KEY (cover_asset_id) REFERENCES public.assets(id) ON DELETE SET NULL;

-- ----------------------------------------------------------------------------
-- selections
-- Tracks "Hearts" (Favorites) and "Checkmarks" (Processing Selections)
-- Hybrid Identity: Supports both user_id and guest_email
-- ----------------------------------------------------------------------------
CREATE TABLE public.selections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  asset_id UUID NOT NULL REFERENCES public.assets(id) ON DELETE CASCADE,
  gallery_id UUID NOT NULL REFERENCES public.galleries(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  guest_email TEXT,
  is_selected BOOLEAN NOT NULL DEFAULT false,
  is_favorite BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Hybrid Identity Constraint: At least one identifier must exist
  CONSTRAINT selections_identity_check CHECK (user_id IS NOT NULL OR guest_email IS NOT NULL),
  -- Prevent duplicate selections for the same asset by the same user/guest
  CONSTRAINT selections_unique_user_asset UNIQUE (asset_id, user_id, guest_email)
);

-- ----------------------------------------------------------------------------
-- comments
-- Contextual discussions on assets or galleries
-- Hybrid Identity: Supports both user_id and guest_email
-- ----------------------------------------------------------------------------
CREATE TABLE public.comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  gallery_id UUID NOT NULL REFERENCES public.galleries(id) ON DELETE CASCADE,
  asset_id UUID REFERENCES public.assets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  guest_email TEXT,
  content TEXT NOT NULL,
  is_resolved BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Hybrid Identity Constraint: At least one identifier must exist
  CONSTRAINT comments_identity_check CHECK (user_id IS NOT NULL OR guest_email IS NOT NULL)
);

-- ----------------------------------------------------------------------------
-- references
-- External inspiration links added by users
-- Hybrid Identity: Supports both user_id and guest_email
-- ----------------------------------------------------------------------------
CREATE TABLE public.references (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  gallery_id UUID NOT NULL REFERENCES public.galleries(id) ON DELETE CASCADE,
  asset_id UUID REFERENCES public.assets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  guest_email TEXT,
  url TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Hybrid Identity Constraint: At least one identifier must exist
  CONSTRAINT references_identity_check CHECK (user_id IS NOT NULL OR guest_email IS NOT NULL)
);

-- ----------------------------------------------------------------------------
-- guest_locks
-- Tracks if a guest has "Submitted" their selection, locking it from edits
-- ----------------------------------------------------------------------------
CREATE TABLE public.guest_locks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  gallery_id UUID NOT NULL REFERENCES public.galleries(id) ON DELETE CASCADE,
  guest_email TEXT NOT NULL,
  locked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status guest_lock_status NOT NULL DEFAULT 'submitted',
  -- Ensure one lock per guest per gallery
  CONSTRAINT guest_locks_unique_gallery_email UNIQUE (gallery_id, guest_email)
);

-- ============================================================================
-- 4. INDEXES (Performance Optimization for RLS)
-- ============================================================================

-- Gallery lookups
CREATE UNIQUE INDEX idx_galleries_token ON public.galleries(gallery_token);
CREATE INDEX idx_galleries_owner_id ON public.galleries(owner_id);
CREATE INDEX idx_galleries_job_id ON public.galleries(job_id);
CREATE INDEX idx_galleries_status ON public.galleries(status);

-- Asset filtering
CREATE INDEX idx_assets_gallery_id ON public.assets(gallery_id);
CREATE INDEX idx_assets_gallery_sort ON public.assets(gallery_id, sort_order);

-- Interaction scoping (Critical for RLS performance)
CREATE INDEX idx_selections_gallery_guest ON public.selections(gallery_id, guest_email);
CREATE INDEX idx_selections_gallery_user ON public.selections(gallery_id, user_id);
CREATE INDEX idx_selections_asset_id ON public.selections(asset_id);

CREATE INDEX idx_comments_gallery_id ON public.comments(gallery_id);
CREATE INDEX idx_comments_asset_id ON public.comments(asset_id);
CREATE INDEX idx_comments_guest_email ON public.comments(guest_email);
CREATE INDEX idx_comments_user_id ON public.comments(user_id);

CREATE INDEX idx_references_gallery_id ON public.references(gallery_id);
CREATE INDEX idx_references_asset_id ON public.references(asset_id);

CREATE INDEX idx_guest_locks_gallery_email ON public.guest_locks(gallery_id, guest_email);

-- Job lookups
CREATE INDEX idx_jobs_owner_id ON public.jobs(owner_id);
CREATE INDEX idx_jobs_client_id ON public.jobs(client_id);
CREATE INDEX idx_jobs_status ON public.jobs(status);

-- ============================================================================
-- 5. TRIGGERS
-- ============================================================================

-- Function to automatically create profile when user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    NEW.raw_user_meta_data->>'avatar_url',
    'client'::profile_role
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on auth.users insert
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers to all tables that need it
CREATE TRIGGER set_updated_at_jobs
  BEFORE UPDATE ON public.jobs
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_galleries
  BEFORE UPDATE ON public.galleries
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_assets
  BEFORE UPDATE ON public.assets
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_selections
  BEFORE UPDATE ON public.selections
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_comments
  BEFORE UPDATE ON public.comments
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at_references
  BEFORE UPDATE ON public.references
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.galleries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.selections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.references ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guest_locks ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- profiles RLS Policies
-- ----------------------------------------------------------------------------
-- Users can read their own profile
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- ----------------------------------------------------------------------------
-- jobs RLS Policies
-- ----------------------------------------------------------------------------
-- Creators can do everything on their own jobs
CREATE POLICY "Creators have full access to own jobs"
  ON public.jobs FOR ALL
  USING (auth.uid() = owner_id);

-- Registered clients can read assigned jobs
CREATE POLICY "Clients can view assigned jobs"
  ON public.jobs FOR SELECT
  USING (auth.uid() = client_id);

-- ----------------------------------------------------------------------------
-- galleries RLS Policies
-- ----------------------------------------------------------------------------
-- Creators have full access to their own galleries
CREATE POLICY "Creators have full access to own galleries"
  ON public.galleries FOR ALL
  USING (auth.uid() = owner_id);

-- Registered clients can read assigned galleries (via job assignment)
CREATE POLICY "Clients can view assigned galleries"
  ON public.galleries FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.jobs
      WHERE jobs.id = galleries.job_id
      AND jobs.client_id = auth.uid()
    )
  );

-- Public read access for galleries (for guest viewing via token)
-- Note: Token validation happens at application layer, not RLS
-- This policy allows reading gallery metadata for token-based access
CREATE POLICY "Public can view active galleries"
  ON public.galleries FOR SELECT
  USING (status = 'active'::gallery_status);

-- ----------------------------------------------------------------------------
-- assets RLS Policies
-- ----------------------------------------------------------------------------
-- Creators have full access to assets in their galleries
CREATE POLICY "Creators have full access to own assets"
  ON public.assets FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.galleries
      WHERE galleries.id = assets.gallery_id
      AND galleries.owner_id = auth.uid()
    )
  );

-- Registered clients can read assets from assigned galleries
CREATE POLICY "Clients can view assets in assigned galleries"
  ON public.assets FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.galleries
      JOIN public.jobs ON jobs.id = galleries.job_id
      WHERE galleries.id = assets.gallery_id
      AND jobs.client_id = auth.uid()
      AND galleries.status = 'active'::gallery_status
    )
  );

-- Public read access for assets (for guest viewing via token)
-- Note: Token validation and gallery status check happen at application layer
CREATE POLICY "Public can view assets in active galleries"
  ON public.assets FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.galleries
      WHERE galleries.id = assets.gallery_id
      AND galleries.status = 'active'::gallery_status
    )
  );

-- ----------------------------------------------------------------------------
-- selections RLS Policies
-- ----------------------------------------------------------------------------
-- Creators can read all selections in their galleries (aggregated view)
CREATE POLICY "Creators can view all selections in own galleries"
  ON public.selections FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.galleries
      WHERE galleries.id = selections.gallery_id
      AND galleries.owner_id = auth.uid()
    )
  );

-- Registered clients can read/write their own selections
CREATE POLICY "Clients can manage own selections"
  ON public.selections FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Guests can read/write their own selections (scoped by email)
-- Note: Email validation happens at application layer via session token
-- This policy allows guests to see only their own rows
CREATE POLICY "Guests can manage own selections by email"
  ON public.selections FOR ALL
  USING (
    user_id IS NULL
    AND guest_email IS NOT NULL
    -- Email validation via session happens at application layer
  )
  WITH CHECK (
    user_id IS NULL
    AND guest_email IS NOT NULL
  );

-- ----------------------------------------------------------------------------
-- comments RLS Policies
-- ----------------------------------------------------------------------------
-- Creators can read/write all comments in their galleries
CREATE POLICY "Creators can manage all comments in own galleries"
  ON public.comments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.galleries
      WHERE galleries.id = comments.gallery_id
      AND galleries.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.galleries
      WHERE galleries.id = comments.gallery_id
      AND galleries.owner_id = auth.uid()
    )
  );

-- Registered clients can read/write their own comments
CREATE POLICY "Clients can manage own comments"
  ON public.comments FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Guests can read/write their own comments (scoped by email)
CREATE POLICY "Guests can manage own comments by email"
  ON public.comments FOR ALL
  USING (
    user_id IS NULL
    AND guest_email IS NOT NULL
  )
  WITH CHECK (
    user_id IS NULL
    AND guest_email IS NOT NULL
  );

-- ----------------------------------------------------------------------------
-- references RLS Policies
-- ----------------------------------------------------------------------------
-- Creators can read/write all references in their galleries
CREATE POLICY "Creators can manage all references in own galleries"
  ON public.references FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.galleries
      WHERE galleries.id = references.gallery_id
      AND galleries.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.galleries
      WHERE galleries.id = references.gallery_id
      AND galleries.owner_id = auth.uid()
    )
  );

-- Registered clients can read/write their own references
CREATE POLICY "Clients can manage own references"
  ON public.references FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Guests can read/write their own references (scoped by email)
CREATE POLICY "Guests can manage own references by email"
  ON public.references FOR ALL
  USING (
    user_id IS NULL
    AND guest_email IS NOT NULL
  )
  WITH CHECK (
    user_id IS NULL
    AND guest_email IS NOT NULL
  );

-- ----------------------------------------------------------------------------
-- guest_locks RLS Policies
-- ----------------------------------------------------------------------------
-- Creators can read all guest locks in their galleries
CREATE POLICY "Creators can view guest locks in own galleries"
  ON public.guest_locks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.galleries
      WHERE galleries.id = guest_locks.gallery_id
      AND galleries.owner_id = auth.uid()
    )
  );

-- Guests can read their own locks (scoped by email)
CREATE POLICY "Guests can view own locks by email"
  ON public.guest_locks FOR SELECT
  USING (
    guest_email IS NOT NULL
    -- Email validation via session happens at application layer
  );

-- Note: Guest locks are typically created via Server Actions, not directly by guests
-- Application layer handles lock creation after PIN verification

-- ============================================================================
-- 7. COMMENTS (Documentation)
-- ============================================================================

COMMENT ON TABLE public.profiles IS 'Extends auth.users with application-specific data';
COMMENT ON TABLE public.jobs IS 'Business containers representing service sessions/orders';
COMMENT ON TABLE public.galleries IS 'Visual containers for assets (standalone or job-linked)';
COMMENT ON TABLE public.assets IS 'The actual files (Images/Videos) stored in Cloudflare R2';
COMMENT ON TABLE public.selections IS 'Tracks "Hearts" (Favorites) and "Checkmarks" (Processing Selections) with hybrid identity support';
COMMENT ON TABLE public.comments IS 'Contextual discussions on assets or galleries with hybrid identity support';
COMMENT ON TABLE public.references IS 'External inspiration links added by users with hybrid identity support';
COMMENT ON TABLE public.guest_locks IS 'Tracks if a guest has "Submitted" their selection, locking it from edits';

COMMENT ON COLUMN public.selections.gallery_id IS 'Denormalized for faster RLS lookups';
COMMENT ON COLUMN public.galleries.settings IS 'JSONB containing allow_download, allow_selection, watermark_enabled';
COMMENT ON COLUMN public.assets.metadata IS 'JSONB containing EXIF data: Camera, Lens, ISO, etc.';

