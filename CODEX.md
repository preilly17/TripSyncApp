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

## Ralph Sprint Workflow (Mandatory on Plan Finalization)

When a plan is approved and ready for execution, you **MUST** scaffold a Ralph sprint before writing any implementation code. This is a blocking requirement.

**Small change exception**: For tasks that touch 1–2 files and have a single, obvious implementation (e.g., a bug fix, copy change, or minor tweak), skip the full Ralph scaffold. Propose the change, get approval, and execute directly.

### Step 1: Create the sprint folder

```text
plans/sprints/YYYY-MM-DD-{slug}/
```

Use today's date and a short kebab-case slug derived from the task.

### Step 2: Generate `prd.json`

Follow `plans/prd.schema.json`. Convert each approved task into a PRD item:

```json
{
  "project": {
    "name": "<sprint title>",
    "repoRoot": "."
  },
  "definitionOfDone": {
    "required": ["All items pass", "Project builds", "No regressions"]
  },
  "items": [
    {
      "id": "<PREFIX>-001",
      "priority": 1,
      "title": "...",
      "description": "...",
      "acceptanceCriteria": ["..."],
      "passes": false,
      "tags": ["..."]
    }
  ]
}
```

Requirements:
- IDs use a short prefix derived from the slug (e.g., `NDP-001`, `PRICE-001`)
- All items start with `"passes": false`
- Every item includes `acceptanceCriteria`
- Add top-level `files_changed` when known

### Step 3: Create `progress.txt`

```text
<Sprint Title>
=====================================================

Started: YYYY-MM-DD
Status: In Progress (0/N items)

## Goals
- <goal 1>
- <goal 2>

## Items

### Priority 1
- [ ] PREFIX-001: <title>
- [ ] PREFIX-002: <title>

### Priority 2
- [ ] PREFIX-003: <title>

## Files to Modify
- <file list>

## Deployment
- <deployment notes, if applicable>
```

### Step 4: Create `prompt.md` (sprint-specific instructions)

Base it on `plans/ralph_prompt.md` and add:
- Verification commands relevant to the sprint (for iOS, include `xcodebuild` commands)
- Domain-specific guidelines and flow-protection notes
- Constraints or gotchas discovered during planning

### Step 5: Print the launch command

After scaffolding, print:

```bash
RALPH_AGENT_CMD=./plans/adapters/claude_code.sh ./plans/ralph.sh plans/sprints/YYYY-MM-DD-{slug} 25
```

### Important

- Do **not** begin implementation until the sprint scaffold is created
- Do **not** skip required artifacts (`prd.json`, `progress.txt`, `prompt.md`, folder)
- If the user says "run it" or "go", scaffold first, then execute interactively

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
