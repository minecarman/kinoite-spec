# ROADMAP.md: kinoite-spec

## Phase 0: Project Setup and Infrastructure
- [X] Create the Cabal project (`kinoite-spec.cabal`, `app/Main.hs`, `src/`)
- [X] Verify GHC 9.4+ and Cabal through `ghcup`
- [X] Bring up the basic CLI skeleton with `optparse-applicative`
  (`--help`, `--version`, `plan`, `apply`)

---

## Phase 1: Type Modeling and Configuration Reading
- [X] Define target-system algebraic data types in `Src.Types.Spec`
  (`SystemSpec`, `OstreeSpec`, `FlatpakSpec`)
- [X] Convert `spec.yaml` into `SystemSpec` with `yaml` and `aeson`
- [X] Add explanatory errors for missing or malformed YAML input
- [X] **Test:** Add unit tests for valid and invalid YAML files

---

## Phase 2: Reading System State (Inspection Layer)
- [X] Run `rpm-ostree status --json` and convert it to `Set PackageName`
- [X] Run `flatpak list --json` and parse installed IDs
- [X] Create `Src.Types.CurrentState` for the combined current state
- [X] **Test:** Verify parser correctness with simulated JSON output

---

## Phase 3: Pure Comparison and Diff Engine
- [X] Define action types in `Src.Types.Action`:
  - `InstallOstree PackageName` / `RemoveOstree PackageName`
  - `InstallFlatpak FlatpakId Scope` / `RemoveFlatpak FlatpakId Scope`
- [X] Implement the pure `CurrentState -> SystemSpec -> [Action]` function
  in `Src.Engine.Diff`
- [X] Test set-difference behavior:
  - Target-only resources -> `Install`
  - Current-only resources -> `Remove`
  - Resources on both sides -> Ignore
- [X] **Test:** Add comprehensive unit tests for the pure diff engine

---

## Phase 4: Terminal Output and Planning (Dry-Run UX)
- [X] Format `[Action]` as readable colored terminal output:
  - Green: `+ Install`
  - Red: `- Remove`
  - Blue: `~ Change / Update`
- [X] Connect `kinoite-spec plan` to the real system diff
- [X] Print `System is already in sync.` when there are no changes

---

## Phase 5: Execution and Convergence (Action Runner)
- [X] Convert `[Action]` into real system commands:
  - `flatpak install/uninstall`
  - `rpm-ostree install/uninstall`
- [X] Integrate user confirmation (`Apply these changes? [y/N]`)
- [X] Safely catch command failures (`ExitFailure`) and report them
- [X] Validate `kinoite-spec apply`

---

## Phase 6: Advanced Features and Refinement
- [X] Inspect Distrobox state and integrate `distrobox create`
- [X] Support Flatpak permission overrides
  (`filesystem`, `environment`, `sockets`)
- [X] Export the current system to YAML with `kinoite-spec export`
- [X] Build a standalone binary and verify it outside Distrobox
