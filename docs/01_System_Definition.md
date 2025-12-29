# StudioFlow — System Definition & Working Context

## 1. Purpose of this document

This document defines the **corrected and authoritative system definition** for the StudioFlow application.

It serves as:

- A **single source of truth** for domain concepts.
- A **stable working context** for AI systems (Gemini as Architect, Claude as Executor).
- A baseline against which all future product and technical decisions must be validated.

This document intentionally focuses on **what is being built and why**, not on implementation details.

---

## 2. Product overview

- **Product name:** StudioFlow (working name)
- **Product type:** SaaS web application

**Core idea:**
StudioFlow is a workflow and delivery platform for content creators (starting with photographers) that centralizes the entire client service lifecycle:

- Client communication
- Preview delivery (proofing)
- Selection and feedback
- Final asset delivery
- Controlled access and archiving

The product replaces fragmented workflows based on WhatsApp, Google Drive, WeTransfer, and email.

StudioFlow is **job-centric where needed** and **gallery-centric where simplicity is required**.

---

## 3. Target users

### 3.1 Creator (primary user)

- Photographer (wedding, event, product, portrait, B2B)
- Works with multiple clients and sessions
- Needs structure, clarity, and control
- Uses desktop primarily, mobile secondarily

**Capabilities:**

- Create galleries
- Create jobs (orders)
- Manage clients
- Upload assets
- Control access and lifecycle

### 3.2 Client (secondary user)

Two client modes are supported:

#### Registered client

- Has an account
- Can log in
- Sees all assigned jobs and galleries
- **Can:**
  - Preview assets
  - Select favorites
  - Comment
  - Download finals (if permitted)

#### Guest client (no account)

- Accesses via secure link
- Email is always required
- **Can:**
  - Preview assets
  - Select favorites
  - Leave comments

**Access is:**

- Permission-limited
- Time-limited

---

## 4. Core problem statement

Creators currently:

- Communicate via messengers
- Send files via generic storage tools
- Track selections manually
- Lose control over access and delivery lifecycle

There is no single, simple, EU-oriented tool that:

- Manages the full service lifecycle
- Provides a clean UX for both creator and client
- Supports both quick galleries and full workflows

StudioFlow solves this by separating **content delivery** from **business workflow**, while allowing them to connect.

---

## 5. High-level system workflow

### Gallery-first workflow (simple)

1.  Creator creates a gallery.
2.  Creator uploads assets.
3.  Gallery is protected by PIN or token.
4.  Client previews assets.
5.  Client selects favorites / comments.

_Used when no formal job tracking is required._

### Job-based workflow (structured)

1.  Creator creates a job (order).
2.  Creator defines assumptions and scope.
3.  Client can view job status and communicate.
4.  Creator creates one or more galleries inside the job.
5.  Galleries are used for proofing and final delivery.
6.  Client selects assets and downloads finals.
7.  Access expires and job is archived.

---

## 6. Core domain model (corrected)

### Gallery

- **Independent domain entity**
- Can exist standalone or be linked to a job
- Always contains assets
- **Access controlled via:**
  - PIN
  - Secure token
- Appears globally in the Galleries section

_A gallery created within a job is visible in the global Galleries view and preserves its association with the job._

### Job (Order)

- **Independent domain entity**
- Represents the business workflow
- **Contains:**
  - Status
  - Assumptions
  - References
  - Client communication
- **May have:**
  - Zero galleries
  - One gallery
  - Multiple galleries

> **Important rule:** A job does **not** own assets directly. It references galleries.

### Asset

- Always belongs to a gallery
- Never belongs directly to a job
- **Has:**
  - Type (image/video)
  - Metadata (size, dimensions)
  - Selection state
  - Comments

### Delivery / Access

- Represents client access rules
- **Can be:**
  - PIN-based
  - Token-based
- **Defines:**
  - Permissions (view, select, download)
  - Expiration

---

## 7. Application areas

The system is built as a **single Next.js application** with clear separation of concerns.

### Marketing area

- Public pages
- SEO-focused
- No authentication

### Creator application

- Authenticated
- Dashboard
- Job and gallery management

### Client delivery area

- Token or PIN-based access
- Minimal UI
- Read / select / download only

---

## 8. Routing philosophy

The application uses route grouping to separate responsibilities:

- Marketing
- Authentication
- Creator app
- Client delivery

Each group:

- Has its own layout
- Has its own access rules

---

## 9. Folder structure philosophy

The project follows a **feature-oriented architecture**.

**Principles:**

- Group by business capability
- Each feature owns:
  - UI
  - Logic
  - Types
  - Data access
- No generic dumping grounds

---

## 10. MVP scope

### Included in MVP

- Creator authentication
- Client authentication (optional)
- Standalone galleries
- Job creation
- Galleries inside jobs
- Proof selection
- Comments
- Final delivery
- Time-limited access
- Archiving

### Explicitly excluded from MVP

- Payments
- Invoicing
- AI features
- Multi-creator collaboration
- Mobile apps

---

## 11. Non-functional requirements

- GDPR-compliant (EU storage)
- Predictable costs
- Simple UX
- Minimal onboarding
- Designed for solo founder development

---

## 12. Technology direction (fixed)

The application will be built using:

- Next.js
- Supabase (database + auth)
- Cloudflare R2 (object storage)
- Tailwind CSS
- Zustand (client state)
- React Query (server state)
- Zod (validation)
- React Hook Form (forms)

---

## 13. AI workflow constraints

- **Gemini** acts as Architect and Product Thinker

  - Gemini does NOT generate code
  - Gemini defines decisions, rules, and plans

- **Claude** acts as Executor
  - Claude writes code
  - Claude operates inside VS Code
  - Claude follows instructions from Gemini

---

## 14. Guiding principles

- Product before implementation
- Simplicity over cleverness
- Explicit decisions over assumptions
- MVP discipline

---

**All future decisions must be evaluated against this definition.**
