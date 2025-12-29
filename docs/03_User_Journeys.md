# 03_User_Journeys.md

Project: StudioFlow
Version: 2.1 (Authoritative)
Status: Approved
Context: Functional Specification for UX/UI and Backend State Machine

## 1. Overview & Core Principles

This document defines the detailed user flows, state transitions, and interaction rules for StudioFlow.
It serves as the primary source of truth for the implementation phase.

### Key UX Principles

- **Mobile-First:** All client-facing interfaces (Guest/Registered) must be optimized for mobile touch interactions.
- **Progressive Disclosure:**
  - **Viewing:** Zero friction. Access via link.
  - **Interacting:** Just-in-time authentication. Email + PIN are required only when an action (selection, comment) is attempted.
- **Identity Persistence:**
  - Guest identity is tied strictly to Email.
  - PIN is an Access Control mechanism, not an identity key.
  - Changing a PIN does not erase data associated with an email.
- **State Clarity:** Clear visual and functional distinction between Proofing (Selection mode) and Delivery (Download mode).

---

## 2. Creator Journeys (The Admin)

### Journey A: The "Quick Gallery" (Direct & Simple)

Context: Creator needs to send photos immediately without setting up a full CRM Job.

1.  **Dashboard Entry**

    - User Action: Logs in → Clicks "New Gallery".

2.  **Configuration**

    - Input: Gallery Name (e.g., "Portrait Session 2024"), Date.
    - System Action: Creates Gallery entity (Status: Draft).

3.  **Asset Management**

    - User Action: Drag & Drop images/videos.
    - System Action: Uploads to R2, generates optimized thumbnails, extracts metadata.

4.  **Access Control Setup**

    - User Action: Toggles "Public Link".
    - User Action: Sets PIN (Optional but recommended).
    - System Action: Generates unique gallery_token.

5.  **Publishing**
    - User Action: Clicks "Publish".
    - System Action: Updates Status Draft → Active.
    - User Action: Clicks "Copy Link" or "Send Invite" (System template).

### Journey B: The "Full Job" Workflow (Business Context)

Context: A structured order (e.g., Wedding) requiring lifecycle management.

1.  **Job Initialization**

    - User Action: Clicks "New Job".
    - Input: Client Name, Email, Job Title, Assumptions (internal notes).
    - System Action: Creates Job entity.

2.  **Gallery Association**

    - User Action: Inside Job view, clicks "Add Gallery".
    - Choice: "Create New Gallery" OR "Link Existing Gallery".
    - System Action: Creates relationship Job <-> Gallery.
    - Note: The Gallery remains visible in the global "Galleries" tab, but is contextually bound to the Job.

3.  **Proofing Phase (Selection)**

    - User Action: Configures Permissions:
      - View: ON
      - Selection: ON
      - Download: OFF
    - User Action: Shares Job Link.
    - System Action: Sets Job Status to Waiting for Selection.

4.  **Review & Export**

    - Trigger: Notification "Selection Submitted" received.
    - User Action: Creator opens Job. Filters view by "Selected by [Client Email]".
    - User Action: Exports filenames for external editing (Lightroom/Capture One).

5.  **Delivery Phase**
    - User Action: Uploads Final Assets (replacing proofs or creating a new sub-folder).
    - User Action: Updates Permissions: Download: ON.
    - System Action: Sets Job Status to Delivered.
    - System Action: Triggers "Ready for Download" notification (email) to Client.

---

## 3. Guest Client Journeys (The Core Experience)

### Journey C: Guest User — Proofing & Interaction

Context: User receives a link. No account exists. Goal: Select favorites, comment, and provide references.

#### Phase 1: Passive Viewing (Zero Friction)

- **Entry:** User clicks link.
- **Edge Case:** Link invalid/typo → Show branded 404 Page.
- **Edge Case:** Gallery Archived → Show "Gallery Archived" message.
- **Landing:** User sees Cover Image + Title.
- **Browsing:** User views Grid. Opens Lightbox.
- **Constraint:** No Email/PIN required yet. Read-only mode.

#### Phase 2: The Interaction Gate (Just-in-Time Auth)

- **Trigger Action:** User attempts ANY of the following:
  - Click Heart (Favorite).
  - Click Checkmark (Select for Processing).
  - Write Comment (on Asset).
  - Add Reference Link (on Asset or Gallery).
- **System Interception:**
  - Modal: "To save your selection, please identify yourself."
  - Field 1: Email (Required - Primary Key for interactions).
  - Field 2: PIN (Required if set by Creator).
- **Validation:**
  - Scenario A (Success): PIN matches. System creates Session. Original action executes immediately.
  - Scenario B (Wrong PIN): Shake animation. "Invalid PIN". (After 5 attempts: temporary block).
  - Scenario C (Wrong Email format): Client-side validation error.

#### Phase 3: The Working Loop

Context: User is now authenticated (Session active).

- **Interactions:**
  - Selection: Toggles Checkmark (System saves to DB).
  - Favorites: Toggles Heart (System saves to DB).
  - Asset Comment: Adds note to specific photo (e.g., "Retouch skin please").
  - Reference: Adds external link (e.g., "Style like this: [URL]") to an Asset or the Gallery globally.
- **Session Persistence:**
  - User closes browser.
  - Returns next day.
  - System Action: Checks LocalStorage/Cookie.
  - If valid: Restores session automatically.
  - If expired: Prompts for PIN/Email again.
  - Data is restored based on Email match.

#### Phase 4: Submission (Handover)

- **Review:** User goes to "My Selections" tab (Review summary).
- **User Action:** Clicks "Submit Selection".
- **System Response:**
  - Locks the selection for this Email (State: Submitted).
  - Prevents further Checkmark toggling.
  - Updates Job Status metadata.
  - Triggers Notification to Creator.

### Journey D: Guest User — Delivery

Context: Job is in "Delivered" state. Download is enabled.

- **Access:** Link → Auth (if PIN set).
- **Dashboard:** "Download All" button is visible.
- **Interaction:**
  - Download All: Triggers ZIP generation/download.
  - Single Download: User opens photo → Clicks "Download".
- **Security Constraint:**
  - If permissions are revoked or Job status reverts to Proofing → Download buttons disappear immediately.
  - Direct URL access to files returns 403 Forbidden.

---

## 4. Registered User Journey (The VIP Experience)

### Journey E: Full Account Lifecycle

Context: Recurring client (e.g., B2B, Wedding Couple).

1.  **Onboarding / Login**

    - Method: Email + Password.

2.  **Client Dashboard**

    - Profile Section: Manage Avatar, Name, Password.
    - Project List: View all associated Galleries/Jobs (Active & Archived).
    - Global Favorites: Aggregated view of all "Hearted" assets across all projects.

3.  **Data Migration (The "Merge")**

    - Scenario: User interacted as Guest (using user@mail.com) before creating an account.
    - System Action: Upon registration/login with user@mail.com, system identifies orphan Guest records.
    - Result: Updates user_id on those records.
    - User sees all past selections in their Dashboard immediately.

4.  **Contextual Communication**
    - Chat System: User opens a Job.
    - Action: Accesses "Messages" tab.
    - Scope: Chat is strictly linked to this specific Job/Gallery.
    - Persistence: History is preserved indefinitely.

---

## 5. Edge Cases & Unhappy Paths

### 1. Security & Access

- **PIN Changed by Creator:**
  - Scenario: Creator changes PIN from 1234 to 9999.
  - User Action: Guest tries to resume session.
  - System Response: Detects PIN mismatch against current config. Invalidates session. Prompts "Security Updated. Enter new PIN."
  - Result: User enters 9999. Access granted. Old data (selections) remains intact (linked to Email, not PIN).
- **Session Timeout:**
  - After X days (e.g., 30), Cookie expires. User must re-authenticate.

### 2. Input Errors

- **Typo in Email:**
  - Guest enters jon@gmil.com (typo) and makes selections.
  - Next day enters jon@gmail.com (correct).
  - Result: System treats this as a new user (empty selection).
  - Resolution: User must use the "wrong" email to recover data, or re-select. (Standard behavior for MVP).

### 3. Concurrency & Conflicts

- **Multiple Guests:** Two users (e.g., Couple) using different emails on the same Gallery.
  - System: Tracks selections separately.
  - Creator sees aggregate view.
- **Shared Account:** Two users using the same email/account simultaneously.
  - System: "Last write wins".
  - UI updates on refresh or optimistic update.
