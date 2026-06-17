---
name: unslop
description: Clean up AI-generated or AI-looking code while preserving behavior. Use when Codex is asked to make generated code idiomatic, remove needless abstraction or boilerplate, reduce over-explanation, align code with the surrounding project style, or perform a human review and cleanup pass without changing product behavior unless explicitly requested.
---

# Code Cleanup / Human Review

Use this skill when asked to clean up AI-generated code.

## Goals

- Preserve behavior unless explicitly asked to change it.
- Make the code idiomatic for the project.
- Remove unnecessary abstraction, defensive boilerplate, generic comments, and AI-looking over-explanation.
- Prefer small, boring, maintainable code.
- Follow the existing project style over generic best practices.
- Run available formatters, linters, type checks, and tests.
- Fix only issues directly related to the cleanup unless asked otherwise.
- Summarize what changed and what checks passed or failed.

## Workflow

1. Inspect surrounding files and project conventions before editing.
2. Identify generated-code smells:
   - needless wrappers
   - excessive comments
   - generic helper names
   - duplicate validation
   - broad try/catch blocks
   - over-flexible options objects
   - premature abstraction
   - inconsistent naming
   - code that ignores existing utilities
3. Refactor in small steps.
4. Run the relevant available checks:
   - formatter
   - linter
   - type checker
   - tests
5. Report remaining risks.

## Cleanup Guidance

- Prefer deleting code over adding new indirection.
- Keep public APIs, data shapes, side effects, error behavior, and user-visible output unchanged unless the user asks for behavior changes.
- Use existing helpers, naming, file organization, and test patterns from nearby code.
- Remove comments that restate the code. Keep comments that explain non-obvious constraints, compatibility issues, or domain rules.
- Replace generic names such as `handleData`, `processItem`, or `utils` only when a clearer local-domain name is evident.
- Narrow broad exception handling when local callers can handle failures directly, but do not remove error handling that protects real user workflows.
- Avoid broad rewrites. If a deeper redesign is tempting, note it as follow-up unless it is required for the requested cleanup.

## Reporting

In the final response, include:

- The main cleanup changes.
- Checks run and whether they passed or failed.
- Any behavior-preservation assumptions or remaining risks.
