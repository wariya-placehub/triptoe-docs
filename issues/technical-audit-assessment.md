# Technical Audit Assessment (April 2026)

This document outlines critical edge cases, security gaps, and architectural risks identified during a comprehensive code review prior to pilot launch.

## 1. Backend: Multi-Tenant Authorization Gaps
**Priority: High**

Currently, several endpoints lack explicit Operator-level validation, which could lead to cross-operator data leakage.

*   **Issue:** Endpoints accepting `tour_template_id` (e.g., `GET /tours/<id>/sessions`) verify the template exists but do not always verify the requesting guide belongs to the same Operator as the template.
*   **Risk:** A guide could theoretically view session data (counts, times) for a different company's tour by guessing the template ID.
*   **Recommendation:** Every endpoint involving a `TourTemplate` must perform `verify_guide_operator_access(guide, tour.operator_id)`.

## 2. Mobile: State Synchronization Race (`useActiveTourStore`)
**Priority: Medium**

The store managing the "Source of Truth" for active tours is susceptible to overlapping async updates.

*   **Issue:** The `refresh` function is async and sets `loading: true`. If multiple refreshes are triggered in rapid succession (e.g., navigating back and forth), an older network response could overwrite a newer one if it arrives late.
*   **Risk:** UI showing stale tracking status or empty lists despite successful data fetching.
*   **Recommendation:** Add a `refreshId` counter or a simple `if (get().loading) return` guard to the `refresh` action in `useActiveTourStore.ts`.

## 3. Messaging: Recipient Validation Gap
**Priority: Medium**

The direct messaging path lacks a "booking boundary" check.

*   **Issue:** In `POST /tour-sessions/<id>/messages`, when a guide sends a message to a specific `recipient_uid`, the backend verifies the guide owns the session but does not verify the recipient actually has a booking for that session.
*   **Risk:** A guide could send messages/notifications to any guest in the database if they know their UID.
*   **Recommendation:** Add a query to verify the `TourBooking` exists for the given `tour_session_id` and `guest_uid` before sending.

## 4. Database: Large-Scale Archival Performance
**Priority: Low**

The current manual loop for archiving bookings during session deletion is atomic but potentially slow.

*   **Issue:** `delete_tour_session` performs a manual loop to create `ArchivedBooking` records. For very large tours (100+ guests), this could lead to request timeouts.
*   **Risk:** Transaction timeout leading to failed deletions.
*   **Recommendation:** Use `db.session.bulk_insert_mappings` for the archival step to handle large guest lists in a single database operation.

## 5. Location: "Urban Canyon" GPS Failures
**Priority: Low**

Static reliance on `Accuracy.High` can cause "Ghost Offline" states in dense areas.

*   **Issue:** In areas with poor GPS visibility (narrow streets, indoors), `Accuracy.High` may fail to get a lock for several minutes.
*   **Risk:** The Guide appears "Offline" on the Guest map despite having a perfect cellular data connection.
*   **Recommendation:** Implement a fallback where if no `High` accuracy fix is received for 2 minutes, the app temporarily drops to `Accuracy.Balanced` to provide a "WiFi/Cell-based" approximate location instead of showing nothing.
