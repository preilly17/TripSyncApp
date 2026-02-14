# Codex Instructions

Read CODEX.md first for full repo workflow + conventions.

## Non-negotiables
- Plan first, then implement.
- Provide numbered task list.
- Keep scope tight; change only required files.
- SwiftUI only, NavigationStack, follow folder conventions.
- No new third-party deps unless explicitly requested.

## Ralph Sprint Workflow (MANDATORY when task > 1–2 files)
When plan is approved and ready for execution:
1) Create sprint folder: plans/sprints/YYYY-MM-DD-{slug}/
2) Create: prd.json (per plans/prd.schema.json), progress.txt, prompt.md
3) Print + run the launch command:
   RALPH_AGENT_CMD=./plans/adapters/claude_code.sh ./plans/ralph.sh plans/sprints/YYYY-MM-DD-{slug} 25

Small change exception:
- If 1–2 files and obvious, skip full Ralph scaffold.

- Use SwiftUI, not UIKit
- Use NavigationStack for navigation
- Folder structure:
  - Networking/
  - Models/
  - Features/<FeatureName>/
  - Shared/UI/
- No third-party libraries unless explicitly requested
- Keep changes scoped to the requested feature
