---
name: agents-md
description: How to write and maintain AGENTS.md files in the winterchill-trading repositories - the root template (purpose, layout, build/test/docs commands, conventions, dependencies, CI, pitfalls, further reading, never-do list), short subdirectory files, the hard content rules (repo-relative paths, no names, facts checked against the repository) and how to refresh them when a repository changes. Use when creating a repository, adding a directory, changing build commands, dependencies or CI, or when asked to add, audit or update AGENTS.md.
---

# AGENTS.md files

Every org repository has an `AGENTS.md` at its root and a short one in each meaningful
subdirectory, so an agent starting anywhere gets the right context in one read. The
workspace-wide guide is `AGENTS.md` at the root of this repository; every repository's
root file links to it as `../oxcaml-claude-skills/AGENTS.md`.

## Outcomes

- A stranger can build, test and change the repository from its `AGENTS.md` alone.
- Every command in the file has been run once and works as written.
- The file stays true: it changes in the same session as the thing it describes.

Reference files: `AGENTS.md` (hub and root file), `skills/AGENTS.md`, `scripts/AGENTS.md`
and `skills/oxcaml-modes/examples/AGENTS.md` in this repository.

## Content rules (hard)

- Repository-relative paths only. Sibling repositories are `../<repo>`: the workspace
  keeps every org repository as a sibling checkout. No absolute path, no home directory,
  no directory outside the repository and its siblings.
- No person names and no company names other than public products and standards; no
  account, machine or unrelated project names. Omit them; do not write sentences about
  what is left out.
- Plain, concrete, current. Derive every fact from the repository (README, `dune-project`,
  dune files, `CHANGES.md`, `.github/workflows/`, `scripts/`) and
  `../specs/repos/<repo>.md`. Never invent a command: run it once
  (`opam exec --switch 5.2.0+ox -- dune build --root .. @<repo>/all`) before writing it.
- Root file under 120 lines; each subdirectory file under 40.
- Commits: author "WinterChill AI <hello@winterchill.xyz>", `docs: add AGENTS.md` or
  `docs: update AGENTS.md for <change>`, no attribution trailers.

## Root template

Sections in this order:

1. **Purpose**: two sentences for a stranger.
2. **Layout**: a table, directory -> what it holds.
3. **Build, test, docs**: from inside the repository in the workspace,
   `opam exec --switch 5.2.0+ox -- dune build --root .. @<repo>/all`, `@<repo>/runtest`,
   `@<repo>/doc`; `DUNE_BUILD_DIR=_build-<repo>` for parallel work (relative to the
   workspace root when `--root ..` is given). Standalone: `opam repo add winterchill
   https://github.com/winterchill-trading/opam-repository.git`, then `dune build`.
   Binaries: the exact `dune exec` line and its main flags.
4. **Conventions**: format with `dune build --root .. @<repo>/fmt --auto-promote` (never
   `dune fmt` across the workspace); `Stable` types with pinned digests; expect tests and
   Quickcheck; allocation pins and the cross-platform rule (pin zero or a range);
   `[@zero_alloc]` where present; comments for humans at non-obvious choices; odoc on
   every public value; a `CHANGES.md` "Unreleased" line for user-visible changes. Keep
   only the ones the repository actually uses.
5. **Dependencies and dependents**: sibling repositories from `dune-project`, the
   repositories that use this one, and the CI pin order.
6. **CI**: what the workflow does (ox-setup cache, pins, obj-magic, docs step, extra
   jobs) and how to check it: one `gh run list --limit 1`, at most one
   `gh run watch <id> --exit-status`, never a polling loop.
7. **Pitfalls**: 3-8 bullets from `../oxcaml-claude-skills/GOTCHAS.md` that bite this
   repository, rewritten for it.
8. **Where to read more**: README, `docs/`, `../specs/repos/<repo>.md`, the skills in
   `../oxcaml-claude-skills/skills/` that apply, and `../oxcaml-claude-skills/AGENTS.md`.
9. **Never do**: install opam packages that change the compiler, `core`, `base`, `async`
   or `ppx_jane`; publish, tag or release; commit credentials (`.env` is gitignored,
   values come from the environment); print secrets; poll CI in loops.

## Subdirectory files

Write one for `lib/` or `src/`, `bin/`, `test/`, `examples/`, `docs/`, `scripts/`,
`bench/` and `.github/` when present; skip generated, fixture-only and tiny directories.
Each says what the directory holds, how it is built or tested, and the one or two rules
that matter there, for example:

- `test/`: how to accept expect output (`dune promote` with the same root and build
  directory) and where fixtures live.
- `bench/`: how allocation and latency pins are measured and on which platform.
- `.github/`: the pins in `ci.yml` must match the org dependencies in `dune-project`.

End each with a pointer to the root file (`../AGENTS.md`).

## Refreshing

Update `AGENTS.md` in the same session, as its own `docs:` commit, when a change:

- adds, renames or removes a directory, library, binary or script (Layout, and a
  subdirectory file for a new meaningful directory);
- changes a build, test or run command or a flag (re-run the command first);
- adds or removes an org dependency, or changes the CI workflow (Dependencies, CI);
- adds a gotcha to `GOTCHAS.md` that affects this repository (Pitfalls).

To audit a repository: run every command in its `AGENTS.md`, compare Layout with
`/bin/ls`, compare Dependencies with `dune-project` and the CI pins, and check the line
counts. A new repository gets its row in the hub's repository map in the same session.

## Exercises

1. Pick a repository and run every command in its `AGENTS.md`; fix any that fail.
2. Add a directory to a scratch copy of a repository and list the `AGENTS.md` edits it
   needs.
3. Check a draft against the content rules: grep it for absolute and home-directory paths, and for names that are neither public products nor standards.
