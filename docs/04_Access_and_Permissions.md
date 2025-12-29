# 04_Access_and_Permissions.md

Project: StudioFlow
Version: 2.2 (Corrected & Enhanced)
Status: Approved
Context: Technical specifications for Supabase Auth, RLS Policies, and Middleware.

## 1. Overview

This document defines the Security Model for StudioFlow. It translates the Functional User Journeys into technical Authentication (AuthN) and Authorization (AuthZ) rules.
Primary Goal: Ensure strict data isolation between Creators, Registered Clients, and Guests.
Technical Context: Implementation will rely on Supabase Auth and PostgreSQL RLS (Row Level Security).

## 2. Actor & Role Definitions

### 2.1 Creator (Role: admin)

- Identity: Authenticated User (auth.users).
- Scope: Owns Galleries, Jobs, Assets.
- Capabilities: Full CRUD (Create, Read, Update, Delete) on resources where owner_id == auth.uid().

### 2.2 Registered Client (Role: client)

- Identity: Authenticated User (auth.users).
- Scope: Assigned to specific Jobs/Galleries.
- Capabilities:
  - READ assigned Galleries.
  - INSERT/UPDATE own Interactions (Selections, Comments).
  - NO ACCESS to other Clients' data.

### 2.3 Guest User (Role: guest)

- Identity: Anonymous (No entry in auth.users).
- Identification: Identified via Session Token linked to an Email + Gallery ID.
- Capabilities:
  - READ Gallery Assets (via Public Token).
  - INSERT Interactions (via Session Token + Email).
  - Strictly Limited: Cannot view other guests' selections unless explicitly aggregated by the system.

## 3. Authentication Mechanisms

### 3.1 Standard Auth (Creators & Registered Clients)

- Provider: Supabase Auth (Email/Password or Magic Link).
- Token: JWT (Access Token).
- Context: request.auth.uid is present.

### 3.2 Guest Access (The "Dual Token" Strategy)

To balance "Low Friction" with "Security", we use two levels of tokens.

**Level 1: Access Token (The "Key to the Door")**

- What is it? A unique string in the URL (e.g., studioflow.pl/g/xyz-123-token).
- Purpose: Allows Reading (Viewing) the Gallery and Assets.
- Security:
  - If PIN is OFF: Public access with the link.
  - If PIN is ON: User must enter PIN to obtain the Level 2 Session or a temporary "View Cookie".

**Level 2: Session Token (The "ID Badge")**

- What is it? A secure token generated after the User provides Email (+ PIN).
- Storage: HttpOnly, Secure, SameSite=Lax Cookie.
- Reason: Prevents XSS attacks (malicious scripts cannot steal the session).
- Note: We avoid LocalStorage for sensitive session data.
- Purpose: Allows Writing (Selecting, Commenting).
- Payload: Encrypted JSON containing gallery_id + email + expiration.
- Cross-Device Logic:
  - The Session is stateless regarding the device.
  - If a User enters email@example.com on Mobile, and later enters email@example.com on Desktop, the RLS policy matches the Email in the row.
  - Access is granted to the same data.
  - Requirement: User must re-authenticate (PIN + Email) on the new device to prove identity.

## 4. Permission Matrix (CRUD)

This section defines the Access Control List (ACL) for each resource type.

**Resource: GALLERY**

- Creator: Full Access (Read/Write) to Own Galleries.
- Registered Client: Read Only (If assigned).
- Guest (Link Only): Read Only (Public info).
- Guest (Verified): Read Only.

**Resource: ASSET (Images/Videos)**

- Creator: Full Access (Read/Upload/Delete).
- Registered Client: Read Only. Download allowed only if Status=Delivered.
- Guest (Link Only): Read Only (View Watermarked).
- Guest (Verified): Read Only.
  - Download allowed only if Status=Delivered.

**Resource: SELECTION (Interaction)**

- Creator: Read All (Aggregated view of all users).
  - Write: None (Cannot alter user selections).
- Registered Client: Read/Write Own rows only.
- Guest (Link Only): No Access.
- Guest (Verified): Read/Write Own rows only (scoped by Email).

**Resource: COMMENT**

- Creator: Read/Write All.
- Registered Client: Read/Write Own.
- Guest (Verified): Read/Write Own.

**Resource: JOB DETAILS**

- Creator: Full Access.
- Registered Client: Read Only (If assigned).
- Guest: No Access (Internal Business Logic).

## 5. RLS (Row Level Security) Strategy

Since we use Supabase, we define Logic Rules for the database.

### 5.1 Assets Policy

- Enable RLS: Yes.
- Policy (Creator): auth.uid() == owner_id.
- Policy (Client/Guest):
  - SELECT allowed IF:
  - exists in galleries WHERE gallery.token == request.token OR gallery.id IN user_assignments.
- Edge Case (Archived/Deleted): If the Gallery is Deleted or Status is Archived (and access is revoked), the query must return 0 rows (equivalent to 404/403).

### 5.2 Interactions Policy (Selections/Comments)

- Enable RLS: Yes.
- Policy (Insert/Update):
  - Creator: Never (Creators don't "select", they "review").
  - Registered: auth.uid() == user_id.
  - Guest: session.email matches row.email AND session.gallery_id matches row.gallery_id.
- Policy (Select/Read):
  - Creator: auth.uid() == gallery.owner_id.
  - Registered: auth.uid() == user_id.
  - Guest: session.email matches row.email.
- Critical Restriction: A Guest cannot query SELECT \* FROM selections WHERE gallery_id = X. They can only see their rows.
- Aggregated views (e.g., "Top Favorites") are reserved for the Creator or calculated via secure Server-Side Functions.

## 6. Token Lifecycle & Rate Limiting

### 6.1 Gallery Link Token

- Creation: Generated when Gallery is created.
- Expiration: Never (unless manually revoked/regenerated by Creator).
- Revocation: Creator clicks "Reset Link" -> New Token generated. Old links return 404/403.

### 6.2 PIN Rate Limiting (Security)

- Threat: Brute-force guessing of the PIN.
- Mechanism: Middleware counts failed attempts per IP + Gallery ID.
- Rule: Max 5 attempts per 10 minutes.
- Action: If exceeded, return 429 Too Many Requests and lock the input UI.

### 6.3 Guest Session (The Cookie)

- Creation: When Guest enters Email + PIN.
- Expiration: 30 Days (Rolling).
- Invalidation:
  - Explicit: Gallery Archived/Deleted (RLS policies will block access even if cookie exists).
  - Explicit: PIN Changed by Creator.
  - Middleware compares "Cookie Issue Date" vs "PIN Last Changed Date". If Cookie is older, force re-authentication.

## 7. Download Protection Strategy

### 7.1 R2 Signed URLs

- Mechanism: The frontend never accesses the R2 bucket directly.
- All downloads go through a backend proxy or signed URL generation.
- Process:
  - User clicks "Download".
  - Server validates RLS permissions (Is Delivered? Is User Authorized?).
  - Server generates a Time-Limited Signed URL.
  - TTL (Time To Live): 1 Hour (URL expires automatically).
- Anti-Abuse:
  - Rate limit the API endpoint (e.g., max 50 download requests per minute per IP) to prevent scraping.
  - No strict bandwidth quota per email for MVP.
