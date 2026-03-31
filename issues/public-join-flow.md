# Public Join Flow for Deep Linking

## Problem
`select-tour-session.tsx` and `join-tour-session.tsx` are inside the `(guest)` group, which requires authentication. If deep linking is added later (Android App Links for `https://triptoe.app/tour-template/{id}`), unauthenticated users scanning a QR code externally (e.g. from a browser) would be redirected to sign-in instead of seeing the tour sessions.

## Current State
Not a problem today. QR codes use `triptoe://` scheme and are only parsed by the in-app camera scanner. Guests are always authenticated by the time they scan.

## When to Address
When implementing Android App Links or any external deep linking that allows users to open the app directly to a tour screen.

## Recommendation
Move `select-tour-session.tsx` and `join-tour-session.tsx` to a top-level `(public)` folder (or handle them in `RootLayout`) so the join flow works for unauthenticated users. Nudge sign-up only when the guest taps "Join" on a specific session.
