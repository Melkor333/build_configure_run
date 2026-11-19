# AGENTS.md

## What this repo is

An experiment: map wildly different tools (ansible, make, systemd, k8s) onto one canonical
dependency graph of the build → configure → run lifecycle. The bet is that anything true of
one tool's subgraph may generalize to all tools mapped to the same nodes.

There is no application code. The "source" is a set of PlantUML fragments plus two Ysh
(Oils) scripts that validate and render them into an SVG/HTML site in `dist/`.

## Commands

```sh
# Build everything (renders dist/index.html, per-tool SVGs, HTML pages)
ysh ./pages.ysh

# Preview one file's PlantUML on stdout (minimal: only edges in that file)
ysh ./diagram.ysh tools/k8s

# Full mode: also emit canonical edges missing from the file as dotted lines.
# Second arg's value is irrelevant, conventionally "b"
ysh ./diagram.ysh tools/k8s b
```

Dependencies: `ysh` (Oils) and `plantuml` must be on `PATH`; use `nix develop` (see
`flake.nix`) to get both. There are no tests and no linter. `dist/` is gitignored build
output.

## CI / deployment

`.github/workflows/gh-pages.yml` builds the site on every push to `main` (via
`nix develop -c ysh ./pages.ysh`) and deploys `dist/` to GitHub Pages with
`actions/deploy-pages`. A local push to main is therefore also a deployment.

## Architecture

Data flow: `templates/` (canonical graph) + `tools/*` (per-tool mappings) → `diagram.ysh`
(validate + assemble PlantUML) → `pages.ysh` (fan out to `plantuml -pipe` in parallel via
`fork`/`wait`) → `dist/`.

- **`templates/flows`** — the canonical edge list (`a --> b` per line). This is the source
  of truth for every connection that exists in the model.
- **`templates/classes`** — PlantUML declarations of the canonical graph participants:
  nodes (`code`, `inputs`, `storage`, `deployment`, `service`, `event`, `snapshot`,
  `blobs`, `metrics`, `process`) and interfaces acting as the stage-like connectors
  (`generate`, `manage`, `store`, `deploy`, `control`, `emit`, `trigger`, `change`,
  `monitor`). Some nodes have display aliases: the identifier is `blobs`/`metrics`, the
  label is "blobs and ir"/"metrics and logs" — flows must reference the identifier.
- **`templates/head`, `templates/end`** — the `@startuml` / `@enduml` wrapper.
- **`00baseline`** — a *symlink to `templates/flows`*, not a regular file. It exists so the
  site renders the canonical graph itself alongside the tools (see the TODO in `pages.ysh`
  about treating it differently).
- **`tools/<name>`** — one file per real-world tool. Lines are `a --> b : label` mappings of
  that tool onto canonical node names. `#line.dashed` marks a weak/indirect relationship.

`diagram.ysh` behaves differently per mode:

- *Minimal* (one arg): validates every edge in the target file against `templates/flows`
  and every node against `templates/classes`, then emits only the target file's edges.
- *Full* (two args): emits the target file's edges **plus** every canonical edge from
  `templates/flows` that the file doesn't mention, annotated `#line.dotted`. So tool files
  only need to state their real connections; dotted lines show unexplored parts of the
  lifecycle.

## Conventions and gotchas

- **Tool files only use canonical names.** Every `X --> Y` edge must have both endpoints
  declared in `templates/classes` and the exact edge text present in `templates/flows`,
  or `diagram.ysh` refuses to render. The error says `template/flows` (singular) but the
  directory is `templates/` — add the edge to `templates/flows`, don't "fix" the path.
- **Edge regex is strict:** the parser matches only `word --> word` (eggex
  `/ <capture w+ > ' --> ' <capture w+ >`). Anything fancier than plain identifiers on
  either side of ` --> ` won't be captured.
- **Adding a new tool:** create `tools/<name>` with edge lines only; validation catches
  typos; then run `ysh ./pages.ysh`. Don't touch `templates/` unless you're intentionally
  evolving the canonical model (that change propagates to all tools via full mode).
- The scripts are Ysh, not bash: `var`/`setvar` declarations, eggex literals `/-regex-/`,
  `fork { ... }` + `wait` for parallelism, `redir > file { ... }` blocks, and `try` /
  `if failed` for error handling. `set -e`-style early exit is *not* automatic —
  `diagram.ysh` deliberately wraps `grep` in `try`/`if failed` to turn grep's exit code
  into a validation error.
- Piping `diagram.ysh` output into `head` can produce a spurious "unknown connection"
  error from the write pipe closing early; check the exit code or redirect to a file
  instead.
