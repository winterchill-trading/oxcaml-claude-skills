# Gotchas log

Dated, append-only. Promote stable entries into `skills/`.

## 2026-10-11

- **Name**: the project is `OxCaml` (oxcaml.org), not `0xCaml`. The opam switch
  is `5.2.0+ox` from `git+https://github.com/oxcaml/opam-repository.git`.
- **depext on macOS**: `opam switch create 5.2.0+ox` needs `autoconf`
  (Homebrew). Non-interactive opam aborts on missing depexts with exit 10
  instead of installing them; run `brew install autoconf` first, or pass
  `--confirm-level=unsafe-yes`.
- **Build time**: the OxCaml compiler is built from source; budget 15-30 min
  on an M-series Mac. Start the switch build in the background before
  scaffolding anything.
