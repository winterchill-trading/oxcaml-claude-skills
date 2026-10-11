# oxcaml-claude-skills

Claude Code skills, gotchas and workarounds collected while building the
`hl-protocol` / `hl-sim` / `hl-mm` projects with [OxCaml](https://oxcaml.org)
and the Jane Street library stack.

Install as a plugin:

```sh
claude plugin add https://github.com/winterchill-trading/oxcaml-claude-skills
```

Or copy a skill directory into `~/.claude/skills/`.

## Skills

| Skill | What it covers |
|-------|----------------|
| `skills/oxcaml-setup` | Creating and maintaining an OxCaml opam switch, CI, depexts |
| `skills/janestreet-ocaml-style` | Writing Base/Core/Async code the Jane Street way, ppx_jane, expect tests |

`GOTCHAS.md` is the running log; entries are promoted into skills once stable.
