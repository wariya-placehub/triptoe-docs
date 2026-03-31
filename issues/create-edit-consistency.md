# Inconsistent Create/Edit Screen Pattern

## Problem
Tour templates use separate files for create and edit, but tour sessions use one file for both.

**Tour Template (separate files):**
- `app/(guide)/create-tour-template.tsx` (48 lines) — thin wrapper, calls `createTourTemplate()`
- `app/(guide)/edit-tour-template.tsx` (91 lines) — thin wrapper, calls `updateTourTemplate()`, has delete
- Both use shared `TourTemplateForm` component

**Tour Session (single file):**
- `app/(guide)/create-tour-session.tsx` (527 lines) — handles both create and edit via `isEditing` flag
- No shared form component — all UI is inline including complex recurrence logic

## Options

### Option A: Split session into two files (match template pattern)
- Extract recurrence UI into a shared `TourSessionForm` component
- Create thin `create-tour-session.tsx` and `edit-tour-session.tsx` wrappers
- Pro: consistent with template pattern
- Con: significant refactor, recurrence logic is complex

### Option B: Merge template into one file (match session pattern)
- Combine `create-tour-template.tsx` and `edit-tour-template.tsx` into one file with `isEditing` flag
- Pro: fewer files, simple change
- Con: template pattern is arguably cleaner as-is

### Option C: Leave as-is
- Both patterns work, inconsistency is cosmetic
- The session file is the outlier but refactoring it is high-effort

## Recommendation
Option A is the cleanest long-term but requires extracting a `TourSessionForm` component from the 527-line file. Do it when the session form needs changes for other reasons.
