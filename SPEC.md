# SPEC.md: kinoite-spec

## 1. Overview and Purpose

`kinoite-spec` is a system convergence engine for managing Fedora Kinoite
systems from a single declarative YAML file. It inspects the system state
(`rpm-ostree`, `flatpak`, and `distrobox`), compares it with the desired
state, displays the required actions (`--dry-run`), and brings the system to
the desired state after confirmation.

---

## 2. Core Architectural Principles

- **Pure business logic (Pure Core, Imperative Shell):** Comparison, sorting,
  and planning perform no `IO`. System inspection and command execution stay
  in the isolated shell layer.
- **Idempotency:** Applying a spec repeatedly produces no side effects when
  the system already matches the desired state (`no-op`).
- **Safety first:** No package or layer may be added or removed without
  explicit user confirmation or the `--yes` flag.

---

## 3. Configuration Schema (`spec.yaml`)

```yaml
version: 1

ostree:
  layered_packages:
    - zsh
    - git
    - tmux

flatpak:
  user:
    - com.spotify.Client
    - com.visualstudio.code
    - md.obsidian.Obsidian
  system:
    - org.mozilla.firefox
  remotes:
    org.kde.kmines: flathub
  overrides:
    com.spotify.Client:
      filesystem:
        - home
      environment:
        - EDITOR=vim
      sockets:
        - wayland

distrobox:
  - name: dev-box
    image: registry.fedoraproject.org/fedora-toolbox:latest
    home: ~/Dev
```

---

## 4. System Inspection and Integration Points

| Layer | Inspection command | Expected format | Output |
|---|---|---|---|
| `rpm-ostree` | `rpm-ostree status --json` | JSON | `deployments[0].requested-packages` |
| `flatpak` | `flatpak list --json` | JSON | `application_id`, `installation`, and `origin` |
| `distrobox` | `distrobox list` | Plain text / CSV | Name and status rows |

---

## 5. Command-Line Interface (CLI)

```bash
# List only differences and the execution plan (default behavior)
kinoite-spec plan --config spec.yaml

# Apply differences (asks for confirmation)
kinoite-spec apply --config spec.yaml

# Apply automatically without asking (for automation/scripts)
kinoite-spec apply --config spec.yaml --yes

# Read the current system and generate a valid spec.yaml
kinoite-spec export > current-spec.yaml
```

---

## 6. Non-Goals

- Writing a package manager (the tool only orchestrates `rpm-ostree` and
  `flatpak` CLI tools).
- Running a background `systemd` daemon or monitoring service.
- Providing a graphical or web UI.
- Calling `sudo` directly as root (the tool runs as the user; `rpm-ostree`
  uses Polkit when required).

---

## 7. Haskell Packages

- `base >= 4.16 && < 5`
- `text`, `bytestring`, `containers`
- `yaml`, `aeson` (configuration and JSON parsing)
- `optparse-applicative` (CLI arguments)
- `typed-process` (safe system command execution)
- `ansi-terminal` (colored diff output)
