# Fatwa Bot Platform — Project Foundation

> Canonical foundation document. Transcribed from `Fatwa Bot Platform — Project Foundation.pdf` (source of truth). Read completely before writing any code.

## Mandate

- The `design/` folder (when present) contains the current reference UI — a baseline, **not** the final product.
- Do not reproduce the existing application. Build a significantly better product.
- Improve UX, UI, navigation, animations, accessibility, feature set, user flows, architecture, and overall product quality wherever it results in a better application.

## Role

Act as: Principal Software Architect · Senior iOS Engineer · Senior Android Engineer · Senior Backend Engineer · Senior System Designer · Senior Product Engineer · Senior UI/UX Engineer.

Think like a company building the best Islamic companion application, not simply another AI chatbot. Challenge weak ideas. Improve features where appropriate. Optimize for long-term maintainability and scalability.

## Vision

An AI-powered **Islamic Companion Platform**. AI is only one part of the product. The application should become one of the most complete Islamic apps available — premium, modern, beautiful, fast, and production-ready, exceeding the current application in usability, quality, performance, and features.

Whenever an additional feature improves the product without making it unnecessarily complex, propose it or implement it.

## Platforms

- iOS Application — SwiftUI, iOS 17+
- Android Application — Jetpack Compose, Kotlin
- Admin Dashboard — Web (completely separate from the mobile applications)
- Backend API

## Architecture

Production-grade architecture, easy to extend for years:

- Clean Architecture
- MVVM-C with Coordinator Pattern
- Factory Dependency Injection
- Feature-first modularization (Core, UICore, Design System, Networking)
- Repository Pattern + Use Cases

## Backend

- **Supabase** is the backend datastore/platform.
- **Firebase** only for: Push Notifications, Analytics, Crash Reporting.
- The mobile applications must **NEVER** communicate directly with Supabase.

```
Presentation → Use Cases → Repositories → APIClient → APIEndpoints → Backend API → Supabase
```

- The backend owns all business logic.
- Mobile apps must never know whether the backend uses Supabase Edge Functions or another technology.
- Use versioned REST APIs. Everything remains replaceable.

## Main Modules

Authentication · Home · Prayer · Qibla · Azkar · Dua · Tasbeeh · Gamification · Leaderboard · Search History · Notifications · Widgets · Settings · AI Search · AI Hadith Extraction · AI Islamic Questions · Admin Dashboard · Configuration · Analytics

## Home

The Home screen contains three AI features:

1. ابحث عن فتوى (Fatwa Search)
2. استخراج الأحاديث (Hadith Extraction)
3. سؤال ديني عام (General Islamic Question)

**Do not implement these first.**

## First Development Priority — the "مزايا" Section

Complete every feature in this section before the AI features:

- Prayer Times
- Qibla
- Azkar
- Dua
- Digital Tasbeeh
- Search History
- Leaderboard

Design these as complete production features.

## Gamification

- Complete streak system: multiple streak categories + one overall streak.
- Streaks represented with the application's own branding (no fire emoji).
- Users may optionally publish a display name.
- Leaderboards: Global and Country.
- Admin can create challenges: for one streak, multiple streaks, or the overall streak.
- Reward system, achievement system, daily challenges, weekly challenges.
- Gamification must remain engaging while respecting the application's Islamic identity.

## Notifications

A powerful notification engine. Examples:

- Third Night reminder
- Before-Adhan reminder
- Before-Iqamah reminder
- Morning Azkar / Evening Azkar
- Daily reminders, challenge reminders, streak reminders

Every notification independently toggleable; configurable reminder offsets; each option has a help icon explaining its purpose.

## Widgets

Built from the beginning, using modern WidgetKit (iOS) and Android App Widgets / Glance:

Prayer Times · Next Prayer · Prayer Countdown · Azkar · Tasbeeh Counter · Daily Challenge · Streak · Hijri Date

## Admin Dashboard

Manages: Users, Prayer Settings, Challenges, Leaderboards, Notifications, Azkar, Duas, Hadith Collections, Fatwa Sources, AI Configuration, Knowledge Base, Announcements, Feature Flags, Application Configuration, Content Management, Analytics.

**The dashboard is the source of truth.**

## AI

- Always prioritize trusted Islamic sources.
- Every answer should include references whenever possible.
- Providers abstracted behind interfaces so they can be replaced later.

## Design

Study the existing designs carefully, but do not copy them blindly. Improve: interactions, navigation, hierarchy, accessibility, spacing, typography, animations, onboarding, empty states, loading states, micro-interactions. The objective is an application visually and functionally superior to the current design.

## Documentation

Maintain throughout development: Architecture documentation, API documentation, ADRs, Roadmap, Changelog, Developer Guides, Setup Guides, Implementation Notes, Future Improvement Notes, Repository Documentation. The repository should be understandable by another senior engineer without additional explanation.

## Development Process

Before writing production code:

1. Analyze the project.
2. Produce a complete implementation roadmap.
3. Review the architecture.
4. Challenge important design decisions.
5. Identify potential improvements.

Then begin implementation. Plan your own milestones. Keep documentation synchronized. Refactor when necessary. Avoid technical debt. Continue until the platform is complete.

Only stop if:

- A major product decision requires approval.
- An architectural decision has multiple valid solutions requiring business input.
- External credentials or assets are required.
