# 07_Out_of_Scope_and_Future.md

Project: StudioFlow
Version: 1.0
Status: Approved
Context: Explicit boundaries for the MVP to prevent scope creep.

## 1. Purpose

This document explicitly lists features and capabilities that are EXCLUDED from the MVP (Minimum Viable Product).
It serves as a guardrail for the engineering team (Claude) to reject complex requests that do not align with the core value proposition.
Rule: If a feature is listed here, it must not be implemented in the first release cycle.

## 2. Explicitly Out of Scope (MVP)

### 2.1 Payments & Invoicing

- Excluded: Integrated payment gateways (Stripe, PayPal, Przelewy24).
- Excluded: PDF Invoice generation.
- Excluded: Tax calculation or accounting integrations.
- MVP Workaround: Creator manages billing externally.
- The system tracks "Status" only (e.g., Creator manually marks a Job as "Paid").

### 2.2 Advanced Image Editing

- Excluded: In-browser cropping, rotation, or filters.
- Excluded: Watermark generation on the fly (Watermarks are applied during upload processing or CSS overlays, not pixel-level manipulation).
- MVP Scope: Images are displayed exactly as uploaded (with optimized resizing).

### 2.3 User Management / Teams

- Excluded: Multi-user teams (e.g., "Second Shooter" accounts).
- Excluded: "Agency" mode (One account managing multiple photographers).
- MVP Scope: Single Creator per account.

### 2.4 Mobile Applications

- Excluded: Native iOS/Android Apps.
- MVP Scope: Fully responsive Mobile Web (PWA-ready).

### 2.5 AI & Machine Learning

- Excluded: Facial recognition (sorting by person).
- Excluded: AI culling or auto-rating.
- Future: This is a high-priority post-MVP candidate.

### 2.6 Complex Archival Storage

- Excluded: AWS Glacier / Deep Archive tiers.
- MVP Scope: All files remain in R2 Standard storage (Hot).

### 2.7 Social Features

- Excluded: "Like" counts visible to other guests (public popularity contests).
- Excluded: Direct sharing to Instagram/FB via API.
- MVP Scope: Native browser "Share" sheet/link copying only.

## 3. Future Roadmap (The Icebox)

These are features planned for V2/V3.
They impact architectural decisions (we leave doors open) but are not built now.

1. Print Store: Integration with a printing lab to order prints directly from the gallery.
2. Lightroom Plugin: Sync selections directly back to LR Catalog (via XML or Plugin).
3. Face Search: Allow clients to find themselves in large event galleries.
4. Client Portal: A polished "Hub" for a client to see all past years' sessions.
5. Watermark Designer: Drag & drop UI to position watermarks.

## 4. Architectural Implications

Because of these exclusions:

- Database: We do not need invoices or payments tables yet.
- Storage: We do not need lifecycle_rules for Cold Storage yet.
- Auth: We do not need organization_id or RBAC (Role Based Access Control) beyond admin vs client.
