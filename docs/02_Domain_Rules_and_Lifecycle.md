# 02_Domain_Rules_and_Lifecycle_Final_EN.md — StudioFlow

## 1. Overview

**Purpose:** This document defines the detailed rules, lifecycles, and interactions of the StudioFlow system.  
It serves as the **primary context for LLMs** (Gemini Pro) to generate actionable instructions for Claude in implementation.

**Scope:** - User types: Guest User, Registered User, Creator

- Objects: Gallery, Job, Asset
- Interactions: Selection, Favorite, Comment, Reference
- Access Control: View vs interaction, PIN + email for Guest Users
- Edge Cases: Archiving, deletion, gallery-job relationships, conflict handling

---

## 2. User Types

### 2.1 Guest User

- **Viewing:** Anyone can view a gallery or job and see images/videos without PIN or email.
- **Interactions:** Require **PIN + email** to perform any interactive action.
- **Available actions after providing PIN/email:** - Mark an asset as **“Selected for Processing”** - Mark an asset as **“Favorite”** - Add a **comment** to an asset, gallery, or job
  - Add **reference links** to an asset, gallery, or job
- **Visibility:** Creator sees all actions with the corresponding guest email.
- **Edge Cases:** - Multiple guest users with the same email → all interactions are linked to that email.
  - If the guest later registers, existing interactions can be migrated to their account.

### 2.2 Registered User

- **Viewing:** Automatically has access to all assigned galleries and jobs.
- **Interactions:** All actions are automatically associated with their account.
- **Additional functionality:** - Dedicated **chat per gallery/job** - User profile with avatar, name, and basic settings
  - View **all favorite assets** - Track interactions: comments, selections, references
- **Edge Cases:** - Interactions from guest usage under the same email can be migrated to the registered account.

### 2.3 Creator

- Main user creating galleries and jobs
- Can create both **standalone galleries** and **job-linked galleries** - Can view guest emails, comments, references, selections, and favorites
- Can manage lifecycle: Archive, delete, restore galleries and jobs

---

## 3. Galleries

### 3.1 General

- Collection of assets (images/videos)
- Types:
  - **Standalone Gallery:** independent, created without a job
  - **Job-linked Gallery:** associated with a specific job, also appears in the “Galleries” tab

### 3.2 Lifecycle

- Statuses: **Active**, **Archived**, **Deleted** - **Rules:** - Archiving a job → linked galleries remain active if standalone
  - Deleting a job → linked galleries remain if standalone, otherwise archived
- **Edge Cases:** - Gallery can belong to multiple jobs (optional, but must handle references/comments correctly)

### 3.3 Access Control

- **Viewing:** Open to everyone without PIN/email
- **Guest User interactions:** - Required **PIN + email** for:
  - Marking assets as **Selected for Processing** - Marking assets as **Favorite** - Adding **comments** or **references** on assets, gallery, or job
- **Registered User interactions:** - Automatic access for assigned galleries
  - All interactions are stored under the user account
  - Can add comments, references, select/favorite assets
  - Access to dedicated chat per gallery

---

## 4. Jobs (Orders)

### 4.1 General

- Jobs are containers representing a service session/order
- Can have multiple galleries associated
- Job-linked galleries appear in both the job view and the global “Galleries” tab

### 4.2 Lifecycle

- Statuses: **Draft**, **Active**, **Completed**, **Archived**, **Deleted** - **Rules:** - Archiving a job → galleries may remain active if standalone
  - Deleting a job → galleries remain if standalone, otherwise archived

### 4.3 Access Control

- **Viewing:** Open to all without PIN/email
- **Guest User interactions:** PIN + email required for:
  - Mark assets as **Selected for Processing** - Mark assets as **Favorite** - Add comments/references to assets, gallery, or job
- **Registered User interactions:** Automatic linking to account + chat access

---

## 5. Assets

- **Creation:** Only by Creator
- **Belongs to:** Always associated with a gallery (standalone or job-linked)
- **Types:** **Image**, **Video** - **Status:** Proof, Selected, Final, Archived, Deleted
- **Interactions:** - Favorite, Selected for Processing, Comment, Reference
  - Interactions tracked with email for Guest Users and account for Registered Users
- **Edge Cases:** - Archiving gallery → Guest User interactions disabled
  - Deleting gallery → assets remain if linked to other galleries
  - Deleting asset → interactions removed or archived

---

## 6. PIN Access

- **Purpose:** Control interactive access for Guest Users
- **Viewing:** Not required for simply viewing galleries/jobs
- **Interactions:** **Required for all Guest User interactions** - **Rules:** - Each PIN tied to specific gallery/job
  - PIN deactivated upon archival/deletion of gallery/job
  - PIN can optionally be reused for multiple galleries/jobs

---

## 7. Interaction Rules

- **Guest User:** email + PIN required for all interactive actions
- **Registered User:** interactions linked to account automatically
- **Actions:** - **Selected for Processing:** marks an asset for processing
  - **Favorite:** marks an asset for quick reference
  - **Comments:** can be added on asset, gallery, job
  - **References:** external links or notes tied to asset, gallery, job
- **Visibility:** Creator sees the user email associated with all interactions
- **Edge Cases:** - Multiple users with same email → all actions linked to that email
  - Migration from Guest → Registered User consolidates actions

---

## 8. Additional Notes

- **All users** can view galleries and jobs anonymously
- **Guest User** can interact only after providing PIN + email
- **Registered User** gets all privileges automatically
- **Creator** has full administrative control, sees all interactions, can manage lifecycle of galleries and jobs
- **Interactivity is always tracked** for traceability and future features (analytics, notifications)
- **Standalone vs Job-linked galleries** are treated distinctly in lifecycle and interaction handling

---
