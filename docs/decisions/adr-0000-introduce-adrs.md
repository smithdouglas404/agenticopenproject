---
status: "accepted"
date: 2026-02-10
decision-makers: Open Project Development Team
consulted:
informed: All developers
---

# Introduce Architecture Decision Records (ADRs)

## Context and Problem Statement

Our software systems are growing in complexity and team size. Architectural and technical decisions are currently communicated verbally, through chat, or buried in pull requests and tickets. As a result, developers often lack context about _why_ a solution was chosen, leading to repeated discussions, inconsistent implementations, and accidental regressions. Additionally, the same problem is solved with different tools within the same codebase, creating a fragmented architecture. We need a way to make architectural decisions transparent, durable, and discoverable across time and teams.

How can we make architectural decisions transparent, durable, and discoverable across time and teams?

## Decision Drivers

- Preserve architectural knowledge over time
- Improve onboarding of new developers
- Avoid repeatedly revisiting the same decisions
- Avoid fragmented architecture with inconsistent solutions
- Provide clear reasoning for non-obvious technical choices
- Support distributed and asynchronous collaboration
- Keep the codebase lightweight and maintainable

## Considered Options

- Do not formally document architectural decisions
- Document decisions in the wiki or as OpenProject work packages of a specific type
- Document decisions in commit messages and pull requests
- Use Architecture Decision Records (ADRs) within the documentation folder

## Decision Outcome

Chosen option: **"Use Architecture Decision Records (ADRs) within the documentation folder"**, because it provides a lightweight, structured, version-controlled method for documenting architectural decisions while keeping documentation close to the codebase and easy to maintain.

### Consequences

- Good, because decisions and their rationale are preserved long-term
- Good, because new team members can quickly understand system architecture
- Good, because future changes can evaluate past trade-offs
- Good, because discussions become more focused and evidence-based
- Good, because ADR change proposals can make use of pull request tooling
- Bad, because writing ADRs adds an overhead to decision making
- Bad, because teams must learn and consistently follow a new process

### Confirmation

Compliance will be confirmed by:

- A repository folder `/docs/decisions/`
- ADRs stored as Markdown files and version-controlled
- Pull request checklist reminding to create an ADR for architectural decisions
- Architecture reviews referencing relevant ADRs
- Periodic audits by the development team

## Pros and Cons of the Options

### Do not formally document architectural decisions

- Good, because no additional process overhead
- Neutral, because decisions can still be discussed informally
- Bad, because knowledge is lost over time
- Bad, because onboarding becomes difficult
- Bad, because decisions are repeatedly debated
- Bad, because teams may implement inconsistent solutions

### Document decisions in the wiki or issue tracker

- Good, because easy to write and familiar to teams
- Good, because searchable
- Neutral, because can hold discussion history
- Bad, because documentation becomes outdated
- Bad, because it is disconnected from the codebase

### Document decisions in commit messages and pull requests

- Good, because documentation lives with code
- Good, because no additional system needed
- Neutral, because reasoning is partially preserved
- Bad, because information is fragmented
- Bad, because difficult to discover or search systematically
- Bad, because PR systems are not designed for long-term documentation

### Use Architecture Decision Records (ADRs) within the codebase

- Good, because decisions are version-controlled alongside the code
- Good, because standardized structure improves clarity
- Good, because easy to review in pull requests
- Good, because chronological numbering provides historical context
- Neutral, because requires minimal process discipline
- Bad, because requires team training and adoption effort

## More Information

ADRs will:

- Be numbered sequentially starting with `ADR-0000`
- Use the MADR template from [https://adr.github.io/madr/](https://adr.github.io/madr/)
- ADRs will be required for significant architectural decisions, such as:
  - introducing a new technology, including:
    - new RubyGems or NPM packages when they are not trivial and introduce new usage patterns (i.e. Angular, React, dry-rb, etc.)
    - introducing new databases or services that need to be included in the deployment process
    - introducing dependencies on external services
  - changing architecture
  - altering system boundaries or APIs
  - making irreversible or costly-to-change decisions
- Be immutable once accepted (updates require a new ADR that supersedes the previous one)
- Be revisited when:
  - the system architecture significantly changes
  - assumptions are no longer valid
  - the decision causes operational or development friction
    This ADR establishes ADRs as the authoritative record of architectural decisions in this project.
