# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [0.17.0] - 2026-03-05

### Added

- Implement skill architecture improvements (spec 001)

### Bump

- Version 0.16.0 → 0.17.0

## [0.16.0] - 2026-03-05

### Added

- Optimize skill descriptions for proactive loading

### Bump

- Version 0.15.0 → 0.16.0

## [0.15.0] - 2026-03-05

### Added

- Add robustness and observability improvements inspired by AIOX

### Bump

- Version 0.14.0 → 0.15.0

## [0.14.0] - 2026-03-04

### Added

- Add SDD workflow based on GitHub Spec Kit

### Changed

- Remove SDD and Ralph Loop for re-implementation

### Bump

- Version 0.13.0 → 0.14.0

## [0.13.0] - 2026-03-03

### Added

- Add reviewer, tester, security, and implementer agents

### Changed

- Replace .devcontainer with plain Docker for Ralph loop

### Bump

- Version 0.12.0 → 0.13.0

## [0.12.0] - 2026-03-03

### Added

- Add Full SDD — /spec design spec generator with OpenSpec-inspired workflow

### Fixed

- Ralph loop resume support and devcontainer improvements

### Bump

- Version 0.11.2 → 0.12.0

## [0.11.2] - 2026-03-01

### Fixed

- Devcontainer build failures with python slim image

### Bump

- Version 0.11.1 → 0.11.2

## [0.11.1] - 2026-03-01

### Fixed

- Make hook scripts executable

### Bump

- Version 0.11.0 → 0.11.1

## [0.11.0] - 2026-03-01

### Added

- Add `marvin dashboard` — live Textual TUI for metrics

### Changed

- Update README for SRP hook refactor and session_logs

### Bump

- Version 0.10.1 → 0.11.0

## [0.10.1] - 2026-03-01

### Changed

- Update README for SDD Light features in v0.10.0
- Add MIT license
- Enforce SRP on hooks — rename, split, and simplify

### Bump

- Version 0.10.0 → 0.10.1

## [0.10.0] - 2026-03-01

### Added

- Add SDD Light — structured criteria, verification, and constitution

### Bump

- Version 0.9.0 → 0.10.0

## [0.9.0] - 2026-03-01

### Added

- Improve researcher agent with effort scaling, search strategy, and eval rubric

### Fixed

- Auto-sync README version badge on release and fix stale 0.7.0 refs

### Bump

- Version 0.8.0 → 0.9.0

## [0.8.0] - 2026-03-01

### Added

- Add path-scoped rules for skills, agents, and hooks authoring

### Bump

- Version 0.7.0 → 0.8.0

## [0.7.0] - 2026-03-01

### Added

- Integrate Ralph Loop autonomous implementation workflow

### Fixed

- Include Ralph loop extras in marvin init and wheel packaging

### Bump

- Version 0.6.1 → 0.7.0

## [0.6.1] - 2026-02-28

### Changed

- Update development standard v1.0 → v1.1
- Enrich skills vs agents decision framework v1.1 → v1.2

### Fixed

- Sanitize newlines and backslashes in metrics JSONL hooks

### Bump

- Version 0.6.0 → 0.6.1

## [0.6.0] - 2026-02-28

### Added

- Align skills with Anthropic official guide

### Bump

- Version 0.5.2 → 0.6.0

## [0.5.2] - 2026-02-28

### Added

- Automate changelog and releases with git-cliff + commitizen

### Fixed

- Improve skill routing descriptions and add skill tracking to logs

## [0.5.1] - 2026-02-27

### Added

- Use rich tables for agents/skills listing and release v0.5.1

## [0.5.0] - 2026-02-27

### Added

- Refactor CLI to installable package and release v0.5.0

## [0.4.0] - 2026-02-27

### Added

- Add 10 expert skills and release v0.4.0

## [0.3.0] - 2026-02-27

### Added

- Unified observability — consolidate metrics + new lifecycle hooks
- Add block-secrets hook for secret exposure prevention

### Changed

- Update changelog for status skill removal
- Expand Marvin identity and remove redundant Standards section
- Add AI engineering to Marvin identity
- Add epistemic discipline to Marvin brain
- Move specs to docs/spec/ subdirectory
- Update changelog for spec directory move
- Remove specs and all spec references
- Add block-secrets.sh to v0.3.0 changelog

## [0.2.0] - 2026-02-26

### Added

- **brain**: Add reasoning, synthesis, and failure recovery
- Mitigate context degradation via hooks and brain constraints
- Researcher v2 and development standard alignment
- Add MCP error monitor hook and fix Context7 tool names

### Changed

- **hooks**: Standardize all hooks to use _lib.sh for JSON parsing
- Reflect brain reasoning cycle in CHANGELOG and README

## [0.1.0] - 2026-02-22

### Added

- Initialize Marvin v0.1.0 project structure
- Add brain, researcher agent, and configuration
- Add session lifecycle and observability hooks
- **hooks**: Capture model, permission mode, and agent IDs

### Changed

- Sharpen brain identity, routing, and agent description
- Update CHANGELOG to reflect current v0.1.0 state
- Update README to reflect current v0.1.0 state

