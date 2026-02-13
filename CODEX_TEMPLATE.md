# CLAUDE.md — Template

> A reusable `CLAUDE.md` for any project using Claude Code.
> Copy this file to the root of your repository, rename it to `CLAUDE.md`,
> and fill in the **[PLACEHOLDER]** sections with your project details.

---

## General Instruction

Before writing any code, **always** produce a detailed, step-by-step plan explaining:
1. The overall approach
2. Key decisions and trade-offs
3. Any assumptions made
4. How the code will be structured and tested

Do not write any code until I explicitly approve the plan.
Once I approve, produce the code with comments mapping back to the plan.

## Style

- Explanations should be clear and concise.
- Code should be clean, modular, and well-commented.
- Prefer clarity over brevity in the plan phase.

## Core Rules

1. **Think in Tasks**
   Treat every prompt as a miniature project. Before writing any code, mentally decompose the request into the smallest practical tasks.

2. **Break Down & Propose**
   Immediately return a concise, **numbered list** of tasks required to satisfy the prompt.
   *Format:*
```
## Proposed Tasks

1. …
2. …
3. …
```
Do **not** begin coding until the user approves or revises the plan.

3. **Seek Explicit Approval**
After listing tasks, ask:
> *"Ready for me to start on Task 1?"* (yes / no / edit plan)
Proceed only on an explicit "yes."

4. **Create a Task Log Folder**
For the current conversation, create / update a folder under `plans/sprints/`:
```
plans/sprints/YYYY-MM-DD-{slug}/
```
Use today's date and a short kebab-case slug derived from the task. Inside, add a markdown file for each task:
`T{n}_{slug}.md` → description, code snippets, decisions.

**Small change exception**: For tasks that touch 1–2 files and have a single, obvious implementation (e.g., a bug fix, copy change, or minor tweak), skip the folder scaffold. Just propose the change, get approval, and execute directly.

5. **Execute Sequentially & Commit Often**
Work through tasks *one at a time*, committing code after each task. After finishing a task, output a one-line status and ask whether to proceed to the next task.

6. **Guarantee Code Quality**
- Follow language & framework best practices.
- Write clean, commented, DRY code.
- Prefer secure defaults; avoid hard-coding secrets.
- If uncertain, pause and ask clarifying questions.

7. **Summarize When Done**
Upon completing all approved tasks, create **SUMMARY.md** in the sprint folder:
- Files added / modified
- High-level overview of changes
- Next recommended steps / optimizations

---

## Project-Specific Context

<!-- Fill in everything below with your project's details. -->

### Project Overview

**[Describe your project in 1–2 sentences. What does it do? Who is it for?]**

### Tech Stack

- **Platform**: [e.g., iOS (Swift/SwiftUI), React, Python/Django]
- **Backend**: [e.g., Firebase, Supabase, PostgreSQL]
- **Architecture**: [e.g., MVVM, MVC, Clean Architecture]
- **Other**: [e.g., AI integrations, third-party SDKs]

### Key Project Structure

```
[Map out your top-level directories and what they contain]
/src
  /models
  /views
  /services
/tests
/docs
```

### Important Commands

```bash
# Build
[your build command]

# Test
[your test command]

# Lint
[your lint command]
```

### Key Features

- [Feature 1]
- [Feature 2]
- [Feature 3]

### Design System

- Primary colors: [hex codes]
- Font: [font family]
- [Link to design docs if applicable]

### API Integrations

- [Service]: [endpoint or docs link]
- [Service]: [endpoint or docs link]

### Security Notes

- [Where secrets are stored]
- [What should never be committed]
- [Security rules or policies]

### UI Consistency Guidelines

<!-- Optional — remove this section if not applicable. -->

When modifying UI views, follow these principles:

1. **When touching existing code**: Update it to follow consistency patterns
2. **When adding new features**: Use shared components if they exist
3. **When you see duplication**: Consider extracting to a shared component
4. **DO NOT**: Refactor working code just for consistency unless explicitly asked

#### Shared Components

- [List reusable components and when to use them]

#### Consistency Checklist (for modified views only)

- [ ] Labels and field order are consistent with other views
- [ ] Using design tokens for colors and spacing
- [ ] Consider extracting if duplicated 3+ times
