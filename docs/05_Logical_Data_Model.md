# 05_Logical_Data_Model.md

Project: StudioFlow
Version: 2.0
Status: Approved
Context: Logical Schema mapping business entities to database structure.

## 1. Overview

This document defines the Logical Schema for the StudioFlow database.
It maps the business entities defined in Domain Rules to database tables, establishing relationships and constraints.

**Key Principles:**

- **Supabase Native:** Designed to work with auth.users and RLS.
- **Hybrid Identity:** Interaction tables (selections, comments) support either a registered user_id or a guest_email.
- **Performance:** Proper indexing on gallery_id and email to support RLS lookups.

## 2. Core Entities (Users & Organization)

### profiles

Extends standard Supabase auth.users with application-specific data.

- **id** (PK): UUID (Foreign Key to auth.users.id, 1:1).
- **full_name**: Text.
- **avatar_url**: Text (Optional).
- **role**: Enum (creator, client).
- **created_at**: Timestamp.

## 3. Workflow Entities (The Business Logic)

### jobs (Orders)

Represents a business container (e.g., "Wedding 2024").

- **id** (PK): UUID.
- **owner_id**: UUID (FK to profiles.id). The Creator.
- **client_id**: UUID (FK to profiles.id, Nullable). If assigned to a registered user.
- **title**: Text (e.g., "Anna & John Wedding").
- **status**: Enum (draft, active, waiting_for_selection, processing, delivered, archived).
- **client_email**: Text (Snapshot of client email for notifications).
- **internal_notes**: Text (Private for Creator).
- **created_at**: Timestamp.

### galleries

The visual container for assets.
Can be standalone or linked to a Job.

- **id** (PK): UUID.
- **job_id**: UUID (FK to jobs.id, Nullable).
  - If null -> Standalone Gallery.
- **owner_id**: UUID (FK to profiles.id).
- **name**: Text.
- **cover_asset_id**: UUID (FK to assets.id, Nullable).
- **gallery_token**: Text (Unique, Indexed). Used for public URL.
- **pin_code**: Text (Nullable). Hashed or plain (hashed recommended).
- **status**: Enum (draft, active, archived, deleted).
- **settings**: JSONB.
  - allow_download: Boolean.
  - allow_selection: Boolean.
  - watermark_enabled: Boolean.
- **published_at**: Timestamp.

## 4. Content Entities

### assets

The actual files (Images/Videos).

- **id** (PK): UUID.
- **gallery_id**: UUID (FK to galleries.id).
- **original_filename**: Text.
- **storage_path**: Text.
  - Path in Cloudflare R2.
- **file_type**: Enum (image, video).
- **width**: Integer.
- **height**: Integer.
- **size_bytes**: BigInt.
- **metadata**: JSONB (EXIF data: Camera, Lens, ISO).
- **sort_order**: Integer. For custom grid arrangement.

## 5. Interaction Entities (The Hybrid Model)

Crucial Design Pattern: These tables handle both Guest and Registered users via a CHECK constraint ensuring at least one identifier exists.

### selections

Tracks "Hearts" (Favorites) and "Checkmarks" (Processing Selections).

- **id** (PK): UUID.
- **asset_id**: UUID (FK to assets.id).
- **gallery_id**: UUID (FK to galleries.id).
  - Denormalized for faster RLS.
- **user_id**: UUID (FK to profiles.id, Nullable).
- **guest_email**: Text (Nullable).
- **is_selected**: Boolean (The "Checkmark").
- **is_favorite**: Boolean (The "Heart").
- **updated_at**: Timestamp.
- **Constraint**: CHECK (user_id IS NOT NULL OR guest_email IS NOT NULL).
- **Unique Constraint**: (asset_id, user_id, guest_email) to prevent duplicate rows.

### comments

Contextual discussions.

- **id** (PK): UUID.
- **gallery_id**: UUID (FK to galleries.id).
- **asset_id**: UUID (FK to assets.id, Nullable). If Null -> General Gallery Comment.
- **user_id**: UUID (FK to profiles.id, Nullable).
- **guest_email**: Text (Nullable).
- **content**: Text.
- **is_resolved**: Boolean (For Creator workflow).
- **created_at**: Timestamp.

### references

External inspiration links added by users.

- **id** (PK): UUID.
- **gallery_id**: UUID (FK to galleries.id).
- **asset_id**: UUID (FK to assets.id, Nullable).
- **user_id**: UUID (FK to profiles.id, Nullable).
- **guest_email**: Text (Nullable).
- **url**: Text.
- **description**: Text.
- **created_at**: Timestamp.

### guest_locks (Logical Control)

Tracks if a guest has "Submitted" their selection, locking it from edits.

- **id** (PK): UUID.
- **gallery_id**: UUID (FK to galleries.id).
- **guest_email**: Text.
- **locked_at**: Timestamp.
- **status**: Enum (submitted, unlocked).

## 6. Entity Relationships

- Creator -> Jobs: One-to-Many.
- Creator -> Galleries: One-to-Many.
- Job -> Galleries: One-to-Many (Usually 1:1, but supports 1:N).
- Gallery -> Assets: One-to-Many (Cascade Delete).
- Asset -> Selections: One-to-Many.
- Asset -> Comments: One-to-Many.
- Profile (Client) -> Interactions: One-to-Many (via user_id).

## 7. Performance & Indexing Strategy

To ensure fast RLS checks (which run on every query), we need specific indexes:

- Lookup by Token: galleries(gallery_token) (UNIQUE).
- RLS Optimization: galleries(owner_id).
- Asset Filtering: assets(gallery_id, sort_order).
- Interaction Scoping:
  - selections(gallery_id, guest_email)
  - selections(gallery_id, user_id)
- Why?
  - RLS policies will frequently check: WHERE gallery_id = X AND email = Y.
