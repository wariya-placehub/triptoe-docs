# Product Overview

Audience: Product Manager, Stakeholders

## Introduction

### What is TripToe?

TripToe is a mobile platform that connects tour guides with their guests during guided walking and bus tours. It solves the common problem of managing groups of tourists in busy, unfamiliar environments — where guests get lost, can't hear the guide, or miss important information.

The platform gives guides real-time visibility into where every guest is, and gives guests a simple way to stay connected to their guide throughout the tour.

### The Problem

Tour guides today face several challenges:

- **Lost guests** — In crowded cities and attractions, guests wander off or fall behind. The guide has no way to know who is missing or where they are.
- **Communication gaps** — Guides shout over traffic noise or use expensive radio equipment. Guests at the back of the group miss instructions.
- **Manual check-ins** — Roll calls waste time. Paper sign-up sheets are error-prone. There's no reliable record of who attended.
- **No post-tour engagement** — Once the tour ends, there's no channel to share recommendations, collect tips, or build a repeat customer relationship.

### The Solution

TripToe provides two connected experiences:

**For Tour Guides:**

- **Create tour templates** — Define reusable tours with a title, description, duration, and meeting point (with map coordinates).
- **Schedule tour instances** — Pick dates and times for upcoming tours. Each instance gets a unique QR code for guest check-in.
- **Track guests in real-time** — See every guest's location on a live map during the tour. Know immediately if someone falls behind or goes the wrong way.
- **Send messages** — Push text messages to all guests or to individual guests. Useful for instructions ("We're moving to the next stop"), alerts ("Meet back here in 15 minutes"), or emergencies.
- **Audio broadcast** — Broadcast voice to all guests' phones during the tour, replacing expensive radio equipment.
- **Post-tour engagement** — Share restaurant recommendations, local tips, or social media links after the tour ends.

**For Tour Guests:**

- **Quick signup** — Designed for walk-up tourists. Minimal friction to create an account and join a tour within minutes.
- **Join via QR code** — Scan the guide's QR code to instantly join the tour. No searching, no typing tour codes.
- **Location sharing** — Opt-in to share location during the tour so the guide can keep track of the group. Location sharing stops automatically when the tour ends.
- **Receive messages** — Get real-time messages from the guide on your phone. Never miss an instruction.
- **Listen to audio** — Hear the guide's broadcast directly on your phone, even in noisy environments.
- **Pay tips** — Tip the guide directly through the app after the tour.
- **Discover nearby tours** — Find tours starting soon near your current location (e.g. "tours starting within 30 minutes within 10 miles").
- **Get recommendations** — Access the guide's restaurant and activity recommendations for the area.

## Key User Journeys

### Guide: Setting up and running a tour

1. Guide creates an account and sets up their profile
2. Guide creates a tour template (e.g., "Historic Rome Walking Tour — 3 hours")
3. Guide schedules a tour instance for a specific date and time
4. On tour day, guide shares the QR code with arriving guests
5. Guide starts the tour and monitors guest locations on the live map
6. Guide sends messages as needed during the tour
7. After the tour, guide shares recommendations and receives tips

```mermaid
flowchart TD
    A[Create Account] --> B[Create Tour Template]
    B --> C[Schedule Tour Instance]
    C --> D[Tour Day: Share QR Code]
    D --> E[Guests Check In]
    E --> F[Monitor Guest Locations on Map]
    F --> G{Need to communicate?}
    G -->|Yes| H[Send Message to Guests]
    H --> F
    G -->|No| I{Tour ended?}
    I -->|No| F
    I -->|Yes| J[Share Recommendations]
    J --> K[Receive Tips]
```

### Guest: Joining and experiencing a tour

1. Guest arrives at the meeting point and sees the guide's QR code
2. Guest scans the QR code, creates a quick account (or logs in)
3. Guest is checked into the tour instance
4. Guest enables location sharing when prompted
5. Guest receives messages from the guide throughout the tour
6. After the tour, guest can tip the guide and view recommendations

```mermaid
flowchart TD
    A[Arrive at Meeting Point] --> B[Scan QR Code]
    B --> C{Have account?}
    C -->|No| D[Quick Signup]
    C -->|Yes| E[Log In]
    D --> F[Check In to Tour]
    E --> F
    F --> G[Enable Location Sharing]
    G --> H[Tour Active]
    H --> I{Receive message?}
    I -->|Yes| J[View Message]
    J --> H
    I -->|No| K{Tour ended?}
    K -->|No| H
    K -->|Yes| L[Location Sharing Stops]
    L --> M[Tip Guide]
    M --> N[View Recommendations]
```

### Guide: Managing multiple check-ins

Some tours have free-time segments (e.g., "Explore the market on your own for 30 minutes"). TripToe supports multiple check-ins per tour instance:

1. Initial check-in at tour start
2. Guests disperse for free time (guide monitors locations)
3. Re-check-in when the group reconvenes
4. Tour continues

```mermaid
flowchart TD
    A[Tour Starts] --> B[Initial Check-In]
    B --> C[Guided Tour Segment]
    C --> D{Free time?}
    D -->|Yes| E[Guests Disperse]
    E --> F[Guide Monitors Locations]
    F --> G[Re-Check-In]
    G --> C
    D -->|No| H{Tour ended?}
    H -->|No| C
    H -->|Yes| I[Tour Complete]
```

## Product Details

### User Types

| User | Description | How they sign up |
|---|---|---|
| **Guide** | Professional or freelance tour guide | Email/password account creation |
| **Guest** | Tourist joining a tour | Quick signup (phone number), or QR code scan |

### Multi-Operator Support

Guides can work for multiple tour operators or companies. TripToe supports this by allowing guides to be associated with different operators, each with their own branding and tour catalog.

### Tour Lifecycle

```
Template Created  →  Instance Scheduled  →  Guests Check In  →  Tour Active  →  Tour Completed
                                                                    │
                                                              Location tracking
                                                              Messaging
                                                              Audio broadcast
```

- **Location tracking** is active only during the scheduled tour window
- **Messages** can be sent during the active tour
- **Post-tour features** (tips, recommendations) are available after completion

### Platform

TripToe is a **mobile-first** application. The product depends on native mobile capabilities — background location tracking and push notifications — that a web app cannot reliably provide. A web browser loses access to location when the user navigates away or closes the tab, and push notifications are limited or unsupported on many mobile browsers. A native mobile app ensures location sharing and message delivery work even when the app is in the background or the screen is off.

- **Guests** use the mobile app exclusively (they are tourists on foot)
- **Guides** use the mobile app during tours (on foot with the group) and can use a web dashboard for tour setup and management if needed in the future

### Success Metrics

- **Guest signup time** — Target: under 60 seconds from QR scan to checked in
- **Location accuracy** — Guests visible on map within 30 seconds of enabling sharing
- **Message delivery** — Push notifications delivered within 5 seconds
- **Guide adoption** — Guides can create and schedule their first tour within 10 minutes of signing up

## Summary

### First Release Features

Implemented in the existing codebase and will carry over.

**Guide Features:**
- Account creation and authentication (email/password)
- Tour template creation and management
- Tour instance scheduling with specific dates and times
- QR code generation for guest check-in
- Multiple check-ins per tour instance (start, after free time, etc.)
- Real-time guest location tracking on interactive map
- Broadcast and direct messaging to guests
- Multi-operator support (guides working for multiple companies)

**Guest Features:**
- Quick signup (phone number) and QR code join
- Check-in to tour instances
- Location sharing with automatic stop when tour ends
- Receive messages from guide
- Booking management

### Future Features

Not yet implemented — planned for later releases.

**Guide Features:**
- Audio broadcasting to guest phones
- Tour analytics and reporting
- Post-tour restaurant and activity recommendations
- Social media sharing

**Guest Features:**
- Nearby tour discovery (find tours starting soon within a given distance)
- In-app tipping
- Listen to guide's audio broadcast
- Access post-tour recommendations
- Push notifications (messages delivered when app is in background)

**Platform:**
- Multi-language support
- Offline mode for areas with poor connectivity
