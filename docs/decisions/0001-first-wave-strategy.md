# ADR 0001: Broad scaffold with vertical contract seams

## Decision

Use a broad first-wave scaffold with vertical contract seams. Build the PRD-shaped monorepo and implement thin, testable seams across protocol, CLI, desktop backend, frontend, renderer, storage, security, observability, and CI.

## Drivers

- The clarified execution direction is broad product build, not MVP-only.
- The PRD makes package boundaries part of the architecture.
- Security defaults and remote terminal ownership must be visible from the first implementation wave.

## Consequences

- Protocol/domain fixtures are the contract gate for dependent lanes.
- Mock/local flows are acceptable only when labeled as mock-only.
- Real SSH/PTY/libghostty integration remains a tracked follow-up until verified with a real environment.
