# Specification Quality Checklist: Rotation, Substitutions, and Durable Data

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-29
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

### Validation summary

- 6 user stories, priorities P1–P3, each independently testable.
- 54 functional requirements across 6 groups; every one maps to an acceptance scenario or edge case.
- 12 edge cases, 11 success criteria, 11 assumptions.
- Zero `[NEEDS CLARIFICATION]` markers. The three questions that would have produced them — number on court, whether the rotation advances automatically or waits for a confirming tap, and how substitutions affect the serving order — were put to the stakeholder and answered before the spec was written.

### Design decisions taken, not dictated

These were not specified by the stakeholder. Each is recorded here so it can be overturned cheaply rather than discovered later.

- **An off-lineup server is recorded, not blocked** (`FR-023`). Picking someone outside the lineup usually means a substitution happened on court that has not been entered yet. Refusing the serve would lose real data to protect a bookkeeping model; the turn is recorded and marked instead, so the discrepancy is visible and correctable.
- **One undo reverses one operator action** (`FR-024`). An automatic advance is reversed together with the serve that caused it. The alternative — undo stepping back through an advance the operator never made — is technically tidier and behaviourally confusing.
- **A lineup is optional** (`FR-014`). A roster of fewer than six is still a usable app; requiring a lineup would make the tracker refuse to work at a practice.
- **Substitution limits are not enforced.** Recorded and counted so the operator can watch the number, never blocked. Caps vary by league and are the referee's to keep.

### Relationship to the previous release

This spec assumes and does not restate the constraints of `001-volleyball-serve-tracker`: phone-portrait only, offline-first, all data local, single operator, opponent score untracked. Those requirements remain in force and are not superseded.

`FR-047` (jersey number only on player buttons) narrows the previous release's picker, which showed a number and a truncated name. No previous requirement is contradicted — `FR-050` keeps full names on the tally board and in statistics, where the space exists.

### Sequencing constraint for planning

User Story 1 must be delivered before any story that writes data in the new shape. Every other story adds to the event record, and shipping any of them before the carry-forward path exists would strand the stakeholder's already-recorded games.

### Open items carried into planning

- None blocking. `/speckit-plan` may proceed.
