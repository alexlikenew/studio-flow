# PROJECT_INSTRUCTIONS.md

**Project:** StudioFlow
**Context:** Coding Standards, Architectural Patterns, and AI Behavior Guidelines.
**Target Audience:** Claude (AI Executor) & Human Developers.

---

## 1. The Prime Directive

You are the **Executor**. You do not invent features. You implement the architecture defined in the `/docs` folder.
Before writing any code, **ALWAYS** check:

1.  `05_Logical_Data_Model.md` for database schema.
2.  `02_Domain_Rules_and_Lifecycle.md` for business logic constraints.
3.  `07_Out_of_Scope_and_Future.md` to ensure you are not building V2 features.

---

## 2. Technology Stack (Strict Enforcement)

- **Framework:** Next.js 15 (App Router).
- **Language:** TypeScript (Strict mode, no `any`).
- **Styling:** Tailwind CSS (Mobile-first). **NO** CSS Modules, **NO** styled-components.
- **HTTP Client:** Native `fetch` (extended by Next.js) or Supabase SDK.
- **State Management:**
  - **Server State:** React Query (TanStack Query v5) - via `@tanstack/react-query`.
  - **Global Client State:** Zustand (Only for complex UI state like modals, sidebar toggles).
- **Forms:** React Hook Form + Zod (Validation).
- **Database/Auth:** Supabase (PostgreSQL + Auth) via `@supabase/ssr`.
- **Icons:** Lucide React.
- **Components:** Shadcn UI (Radix Primitives + Tailwind).

---

## 3. Architectural Pattern: Feature-Sliced Design (FSD)

We strictly follow the directory structure defined in the project root. **DO NOT** create generic folders like `/hooks` or `/components` at the root.

### Hierarchy of Imports (Strict Rule)

You may import strictly "downwards":
`app` -> `views` -> `widgets` -> `features` -> `entities` -> `shared`.

- **Forbidden:** `entities` importing from `features`.
- **Forbidden:** `shared` importing from `entities`.

### Layer Definitions

1.  **`app/`**: Routing only. `page.tsx`, `layout.tsx`, `route.ts`. **NO** complex logic here.
2.  **`views/`**: Page composition. Combines Widgets.
3.  **`widgets/`**: Large, self-contained UI blocks (e.g., `Header`, `GalleryGrid`, `Sidebar`). Connects Features to Entities.
4.  **`features/`**: User interactions (e.g., `AuthForm`, `LikeButton`, `DownloadPack`). Contains business logic tied to an action.
5.  **`entities/`**: Domain models (e.g., `User`, `Gallery`, `Asset`). Contains TypeScript interfaces and simple display components (e.g., `UserAvatar`).
6.  **`services/`**: Business Logic Layer / Use Cases (Pure functions, no UI). Handles complex scenarios (e.g., `submit-selection.ts`, `verify-pin.ts`).
7.  **`shared/`**: Generic utilities, UI kit (Buttons, Inputs), API clients.

---

## 4. Coding Standards

### 4.1 Data Fetching & API Separation

**NEVER** mix database logic directly inside Client Components.

- **Server Components:** Use `shared/api/server/supabase.ts` for direct DB calls using `cookies()`.
- **Client Components:** Use **React Query** hooks calling **Server Actions**.
- **Mutations:** ALWAYS use Server Actions (`actions.ts` inside feature/service) + `useMutation`.

### 4.2 Styling (Tailwind + Utils)

- Use `clsx` and `tailwind-merge` via the `cn()` utility for dynamic classes.
- Do not hardcode colors; use CSS variables defined in `globals.css` (e.g., `bg-primary`, `text-muted-foreground`).

### 4.3 Forms (Zod + React Hook Form)

- Define schemas in a separate file (e.g., `schema.ts`) within the feature folder.
- Infers types from Zod: `type FormData = z.infer<typeof schema>`.
- Always handle `isSubmitting` and server errors visually.

### 4.4 Types

- **Database Types:** Import from `database.types.ts` (Supabase generated).
- **Domain Types:** Re-export clean types in `entities/{entity}/model/types.ts`.
- **Props:** Use `interface Props` for component props.

---

## 5. Development Workflow (Step-by-Step)

When implementing a new feature (e.g., "Guest Selection"):

1.  **Check Domain Rules:** Read `02_Domain_Rules_and_Lifecycle.md` to understand the logic.
2.  **Define Schema:** Update/Check `05_Logical_Data_Model.md` and `entities/` types.
3.  **Create Service:** Implement business logic in `services/selection/toggle-selection.ts`.
4.  **Create Server Action:** Expose the service via a Server Action (e.g. `features/select-asset/actions.ts`).
5.  **Build UI Feature:** Create `features/select-asset/ui/SelectionToggle.tsx` using `useMutation`.
6.  **Compose:** Add the feature to `widgets/gallery-grid`.

---

## 6. Common Pitfalls to Avoid

1.  **No "useEffect" Data Fetching:** Do not use `useEffect` to fetch data. Use `useQuery` or Server Components.
2.  **No "Layout Thrashing":** Don't import heavyweight libraries in the Root Layout.
3.  **Client/Server Boundary:** Be careful not to import server-only modules (like `cookies()`) into files marked `"use client"`.
4.  **Environment Variables:** Access public vars via `process.env.NEXT_PUBLIC_...` and private vars via `process.env...`.
5.  **Ghost Loading:** Always implement `Suspense` boundaries or `isLoading` states for async data.

---

## 7. AI Persona Instructions

- **Be Concise:** Don't explain "why" unless asked. Show the code.
- **Be Modular:** If a file gets too long (>200 lines), suggest splitting it.
- **Be Safe:** Always validate inputs (Zod) on the server side, even if validated on the client.
- **Strict Architecture:** If you see a file deviation from FSD (e.g., creating `src/hooks`), correct it immediately.

**End of Instructions**
