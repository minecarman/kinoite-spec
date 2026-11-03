# CONVENTIONS.md: Kinoite-Spec Coding and Architecture Standards

This document defines the rules that all Haskell code and system interactions
in the `kinoite-spec` project must follow. AI assistants must follow these
rules strictly when generating code.

## 1. Architecture: Pure Core, Imperative Shell

- **Business logic must be pure:** All functions that compare `rpm-ostree`
  and `flatpak` lists, make decisions, or sort results must be pure. Their
  type signatures must never contain `IO`.
- **IO only at the edges:** File reads (`yaml`), command execution
  (`typed-process`), and terminal output may only appear in the outer
  application shell (`Main` or `Runner` modules).

## 2. Haskell Coding Standards

- **Explicit type signatures:** Every top-level function, value, and data
  type must have an explicit type signature. Do not rely on type inference.
- **Partial functions are forbidden:** Never use `head`, `tail`, `fromJust`,
  `!!`, `error`, or `undefined`, which can crash the program. Use pattern
  matching, `Maybe`, or `Either` instead.
- **Text/ByteString instead of String:** Use `Data.Text` for text processing
  and `Data.ByteString` for file or socket data for performance and memory
  safety. Enable the `OverloadedStrings` extension when necessary.
- **Strong types (`newtype`):** Use wrapper types instead of plain text to
  prevent different IDs from being mixed (for example,
  `newtype FlatpakId = FlatpakId Text`).

## 3. Fedora Kinoite and System Interaction

- **No sudo/root assumptions:** `kinoite-spec` runs as a regular user and
  must never call `sudo` directly. `rpm-ostree` uses Polkit for system-level
  authorization, while Flatpak uses `--user` or `--system` as appropriate.
- **JSON parsing instead of regex:** System tools should be called in JSON
  mode (`rpm-ostree status --json`, `flatpak list --json`) and parsed with
  strongly typed `aeson` types. Do not analyze stdout with regex or ad-hoc
  text splitting.
- **Safe command execution:** Always use the safer, modern `typed-process`
  library instead of `System.Process` for external commands.

## 4. AI Guidance

- **Progress step by step:** Before adding a feature, check `ROADMAP.md` and
  implement only the requirements of the current phase. Avoid scope creep.
- **Dependency review:** Ask the user for approval before adding a new
  external package to `kinoite-spec.cabal`.
- **Keep documentation current:** When a phase is successfully tested and
  completed, offer to mark its item as `[x]` in `ROADMAP.md`.
