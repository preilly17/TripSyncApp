# CODEX.md — TripSyncApp

This file defines how Codex should work in this repository.

## General Instruction

Before writing code, provide a concise implementation plan with:
1. Overall approach
2. Key decisions and trade-offs
3. Assumptions
4. How changes will be validated

For small, obvious edits (1–2 files), a short plan is sufficient.

## Style

- Keep explanations concise and practical.
- Favor readable, modular Swift code.
- Add comments only where intent is not obvious.

## Core Rules

1. **Plan first, then implement**
   - Share a numbered task list before making edits.

2. **Keep scope tight**
   - Only change files required for the requested feature/fix.

3. **Use project conventions**
   - SwiftUI (not UIKit)
   - `NavigationStack` for navigation
   - Folder layout:
     - `Networking/`
     - `Models/`
     - `Features/<FeatureName>/`
     - `Shared/UI/`

4. **No unnecessary dependencies**
   - Do not add third-party libraries unless explicitly requested.

5. **Quality checks**
   - Prefer static review when runtime tooling is unavailable.
   - If commands are run, report exact commands and outcomes.

6. **Summarize completion**
   - List changed files and a brief validation summary.

---

## Project-Specific Context

### Project Overview

TripSyncApp is an iOS SwiftUI app for trip coordination. It supports authentication and viewing trip-related travel data, including flights and hotels, via API-backed features.

### Tech Stack

- **Platform**: iOS (Swift / SwiftUI)
- **Networking**: Native `URLSession`
- **Architecture**: Feature-oriented SwiftUI with API service structs and model types
- **Dependencies**: No third-party libraries in the current codebase

### Key Project Structure

```text
TripSyncClean/
  TripSyncCleanApp.swift
  ContentView.swift
  Networking/
    APIClient.swift
    APIError.swift
    AuthAPI.swift
    TripsAPI.swift
    FlightsAPI.swift
    HotelsAPI.swift
  Models/
    User.swift
    Trip.swift
    TripCalendar.swift
    Flight.swift
    FlightProposal.swift
    Hotel.swift
    Destination.swift
  Features/
    Auth/
      AuthGate.swift
      AuthViewModel.swift
      LoginView.swift
    Trips/
      TripsListView.swift
      TripDetailsView.swift
      FlightsListView.swift
      HotelsListView.swift
      FlightDetailView.swift
      ProposalsTabView.swift
      AddFlightSheetView.swift
      AddHotelSheetView.swift
      HotelsListViewModel.swift
      TripDateFormatter.swift
  Shared/
    UI/
      FlightDateFormatter.swift
```

### Important Commands

```bash
# Open in Xcode
open TripSyncClean.xcodeproj

# Build (simulator)
xcodebuild -project TripSyncClean.xcodeproj -scheme TripSyncClean -sdk iphonesimulator build

# Test (if tests are added)
xcodebuild -project TripSyncClean.xcodeproj -scheme TripSyncClean -sdk iphonesimulator test
```

### Key Features

- Cookie/session-based authentication flow (`AuthGate`, `AuthViewModel`, `AuthAPI`)
- Trips listing and trip detail browsing
- Flight and hotel browsing for trips, including proposal-related views

### API Integrations

- Base URL configured via `Info.plist` key: `API_BASE_URL`
- Auth endpoints under `/api/auth/*`
- Trips endpoints under `/api/trips`
- Flights and hotels APIs under corresponding `/api/*` paths in networking services

### Security Notes

- Do not hardcode credentials or secrets in source files.
- Keep environment-specific endpoints in configuration (`Info.plist`) rather than code.
- Session uses cookies managed by `URLSession`/`HTTPCookieStorage`.

### UI Consistency Guidelines

- Reuse shared formatting/helpers in `Shared/UI/` and feature formatters where applicable.
- Preserve existing SwiftUI patterns and screen flow.
- Avoid broad refactors unless requested.
