# skills/

One directory per Claude Code skill. Each holds a `SKILL.md` whose YAML front matter has
`name` (the directory name) and `description` (what it covers and when to use it; this is
what triggers the skill, so name the concrete terms a request would contain).

- A skill opens with outcomes, 3-5 reference modules from the org repositories and short
  exercises for checking a fresh session against it.
- Claims about compiler behaviour or allocation belong in an `examples/` dune project
  that CI builds and tests, not only in prose.
- Promote stable entries from `../GOTCHAS.md` into the matching skill; leave the log
  entry in place.
- A new skill gets a row in the README "Skills" table in the same commit.
- Markdown only changes need no build. For `examples/`, see the `AGENTS.md` there.

Workspace guide: `../AGENTS.md`.
