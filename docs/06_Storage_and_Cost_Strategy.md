# 06_Storage_and_Cost_Strategy.md

Project: StudioFlow
Version: 1.1
Status: Approved
Context: Infrastructure decisions for file storage, optimization, and cost management.

## 1. Overview

This document defines the physical storage strategy for StudioFlow.
It addresses the high-volume data requirements of a photography workflow platform while maintaining predictable costs for a solo founder.
Core Technology: Cloudflare R2. Why:

1. Zero Egress Fees: Essential for "Delivery" features (heavy ZIP downloads).
2. S3 Compatibility: Works with standard AWS SDKs in Next.js.

## 2. Bucket Architecture

We will use a Single Bucket architecture with strict path-based tenancy.

### 2.1 Path Structure

The directory structure enforces isolation by owner_id (The Creator).
Format: {owner_id}/{gallery_id}/{asset_id}/{variant_name}.{ext}
Example:

- user_123_uuid/gallery_abc_uuid/asset_xyz_uuid/original.jpg
- user_123_uuid/gallery_abc_uuid/asset_xyz_uuid/preview.webp
- user_123_uuid/gallery_abc_uuid/asset_xyz_uuid/thumb.webp

**Why this structure?**

- Isolation: Easy to calculate storage usage per Creator (owner_id prefix).
- Cleanup: Deleting a Gallery is just deleting the {gallery_id} prefix.
- Performance: Spreads keys evenly.

## 3. Asset Variants & Optimization

For every uploaded image, we generate specific variants to balance Quality vs. Speed vs. Storage Cost.

**Variant 1: Original (Master)**

- Resolution: Full Resolution (Unchanged).
- Format: Keep Original (JPG).
- Quality: 100% (Bit-perfect copy).
- Usage: Final Delivery (Download).
- Access: Locked. Only accessible via short-lived Signed URLs when status is "Delivered".

**Variant 2: Preview (Lightbox)**

- Resolution: Max Width/Height 2048px.
- Format: WebP.
- Quality: 85%.
- Usage: Full-screen Lightbox viewing.
- Access: Public/Token. Served via CDN. (Optional: Watermarked version in future).

**Variant 3: Thumbnail (Grid)**

- Resolution: Max Width/Height 400px.
- Format: WebP.
- Quality: 80%.
- Usage: Gallery Grid view.
- Access: Public/Token. Served via CDN.

**Storage Impact Estimation:**

- Overhead: A typical 15MB original generates only ~600KB of optimized variants (approx. 4% overhead).
- Strategy: We always keep the Original. We optimize UI variants for speed.

## 4. The Upload Workflow (Direct-to-R2)

To save server CPU and bandwidth, we do not stream files through the Next.js server.

1. Frontend: Request "Upload URL" for file my-photo.jpg.
2. Backend:
   - Checks permissions.
   - Generates R2 Presigned URL (PUT).
   - Creates Asset record in DB (Status: uploading).
3. Frontend: Pushes file directly to Cloudflare R2 using the Presigned URL.
4. Trigger: Client calls api/assets/process (MVP) or R2 Event triggers Worker (Scale).
5. Processing:
   - Backend downloads file (or uses Worker).
   - Generates Thumb/Preview variants.
   - Extracts Metadata (Exif).
   - Updates DB Status to ready.

## 5. The Delivery Workflow (Downloads)

1. User Action: Clicks "Download All".
2. Backend Validation:
   - Checks RLS permissions (Is Status Delivered?).
3. Process:
   - Direct Download: For single files, generate a Signed URL.
   - ZIP Download: Stream files via a Backend Service piping R2 streams to the Client Response.
   - Note: We avoid generating static ZIP files on disk to save storage space.

## 6. Cost Optimization Rules (MVP)

### 6.1 No Cold Storage

We will not implement "Glacier/Cold Storage" tiers in MVP.

- Reason: Adds immense complexity (retrieval times, async UI).
- Strategy: R2 storage is cheap ($0.015/GB).
- We keep everything "Hot" for immediate access.

### 6.2 Deletion Policy (Soft vs. Hard)

- Database: Soft Delete (deleted_at flag) allows undo.
- Storage (R2):
  - When a Gallery is "Deleted" in UI -> Mark DB as deleted.
  - Cron Job (e.g., 7 days later): Permanently delete files from R2.
  - Why: Prevents accidental data loss while ensuring we stop paying for deleted content eventually.

### 6.3 Image Optimization

We use WebP for all UI-facing assets. It saves ~30% bandwidth vs JPG, speeding up the client experience.

## 7. Security Context

- Public Access: R2 Bucket is Private by default.
- CDN Access: We configure a Cloudflare Custom Domain (e.g., cdn.studioflow.pl) that sits in front of R2.
- Access Control:
  - Originals: Only accessible via Short-lived Signed URLs (Backend validation required).
  - Previews/Thumbs: Accessible via CDN, but file paths rely on unguessable UUIDs (asset_id).

## 8. Abuse Protection & Fair Use Policy

To prevent scraping, hotlinking, and excessive resource consumption (which affects CPU/Serverless costs despite free R2 egress), we implement basic throttling rules.

### 8.1 Bandwidth Throttling (Downloads)

Since ZIP generation/streaming consumes server/worker compute time:

- Rule: Max 5 ZIP downloads per hour per IP address for a specific Gallery.
- Action: If exceeded, return 429 Too Many Requests with a "Please wait before downloading again" message.
- Goal: Prevents a single user from triggering massive compute spikes by repeatedly clicking "Download All".

### 8.2 Request Rate Limiting (Previews)

To protect against automated scrapers and hotlinking:

- Rule: API Rate Limit of 200 requests per minute per IP for asset endpoints.
- Context: This allows fast scrolling for legitimate users but blocks aggressive scraping scripts.
- Implementation: Handled via Next.js Middleware or Cloudflare WAF (if enabled).

### 8.3 Hotlinking Protection

- Referer Check: The CDN/Image API verifies the Referer header.
- Policy: Assets are only served if the request originates from \*.studioflow.pl.
- Exception: Direct "Original" downloads (Signed URLs) do not require a referer check as they are token-protected.
