# kinoite-spec

A Haskell-based system convergence engine for managing Fedora Kinoite from a
declarative YAML specification.

## Status

The project currently covers Phase 6:

- Convert YAML configuration into strongly typed Haskell values
- Parse `rpm-ostree status --json`
- Separate user and system installations from `flatpak list --json`
- Represent the current system state
- Calculate differences between current and desired state
- Produce colored plans with `plan --config`
- Execute actions with confirmation or `--yes`
- Inspect Distrobox state and create missing containers
- Export the current state to YAML with `export`
- Apply Flatpak `filesystem`, `environment`, and `sockets` overrides
- Select a per-application Flatpak `remote` when needed

Flatpak override example:

```yaml
flatpak:
  remotes:
    org.kde.KMines: flathub
  overrides:
    com.example.App:
      filesystem:
        - home
      environment:
        - EDITOR=vim
      sockets:
        - wayland
```

## Requirements

- Git
- GHC 9.4 or newer and Cabal
- `rpm-ostree`, `flatpak`, and preferably `distrobox` on Fedora Kinoite

VS Code is not required. The following commands can be run from a regular
terminal.

## Terminal installation

Clone the project and enter its directory:

```bash
git clone https://github.com/minecarman/kinoite-spec.git
cd kinoite-spec
```

If GHC and Cabal are not installed, install them with
[GHCup](https://www.haskell.org/ghcup/):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
```

Follow the installer's prompts, then reopen the terminal or load the updated
PATH:

```bash
source "$HOME/.ghcup/env"
```

Build and install the executable:

```bash
cabal install exe:kinoite-spec \
  --installdir="$HOME/.local/bin" \
  --overwrite-policy=always
```

Add the install directory to the current shell:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

To make this permanent for Bash:

```bash
printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
source "$HOME/.bashrc"
```

Verify the installation:

```bash
command -v kinoite-spec
kinoite-spec --help
```

## Usage guide

### Create a configuration from the current system

Run this once to create a starting configuration:


```bash
kinoite-spec export > current-spec.yaml
```

The exported file contains:

- Host rpm-ostree layered packages
- User and system Flatpak applications
- Detected Flatpak `remote` values
- Distrobox names and images
- Supported Flatpak overrides

Packages installed inside a Distrobox, such as Python, Haskell, or VS Code,
are not exported; the tool manages the Distrobox container itself.

### Plan before applying changes

Always inspect the plan first:

```bash
kinoite-spec plan --config current-spec.yaml
```

`System is already in sync.` means the current and desired states match.
`+` means install/create, `-` means remove, and `~` means an override change.

If the output contains an unexpected removal, do not run `apply`. Edit the
YAML or generate a fresh export first.

### Edit the configuration

Add host packages:

```yaml
ostree:
  layered_packages:
    - vim
    - zsh
```

Add a Flatpak:

```yaml
flatpak:
  system:
    - org.kde.kolourpaint
  remotes:
    org.kde.kolourpaint: fedora
```

If an application exists in multiple remotes, specify one under `remotes`.
The selected remote is passed explicitly to the install command.

### Apply changes

After reviewing the plan, apply with confirmation:

```bash
kinoite-spec apply --config current-spec.yaml
```

The program displays `Apply these changes? [y/N]`. Type `y` and press Enter
to continue. Automation can skip the prompt:

```bash
kinoite-spec apply --config current-spec.yaml --yes
```

`apply` can modify the real system through rpm-ostree, Flatpak, and Distrobox.
Existing packages or Flatpaks not listed in the YAML may be planned for
removal, so never run `apply` before reviewing the `plan` output.

### Distrobox

Inside Distrobox, the tool reaches host commands through
`distrobox-host-exec`. Outside Distrobox, it calls the commands directly.
Example:

```yaml
distrobox:
  - name: dev-box
    image: registry.fedoraproject.org/fedora-toolbox:latest
```

Packages inside the container are not managed declaratively.

### Safe testing

Work on a copy before changing your real specification:

```bash
cp current-spec.yaml /tmp/kinoite-spec-test.yaml
kinoite-spec plan --config /tmp/kinoite-spec-test.yaml
```

OSTree operations may create a new deployment and can fail because of package
repository conflicts. If that happens, check `rpm-ostree status`; the tool
reports the failed command and a failed transaction does not create a
successful deployment.

### Updating kinoite-spec

Run these commands from the cloned project directory whenever the source code
changes:

```bash
git pull
cabal install exe:kinoite-spec \
  --installdir="$HOME/.local/bin" \
  --overwrite-policy=always
```

### Uninstalling the binary

The binary can be removed without changing the managed system:

```bash
rm -f "$HOME/.local/bin/kinoite-spec"
```

## Build and test

```bash
cabal build
cabal test config-tests
```

Tests do not run real system commands; they validate parser behavior with
sample JSON output.

To install a standalone binary under `~/.local/bin`:

```bash
cabal install exe:kinoite-spec --installdir="$HOME/.local/bin" --overwrite-policy=always
```

Inside Distrobox the binary uses `distrobox-host-exec`; outside Distrobox it
calls `rpm-ostree`, `flatpak`, and `distrobox` directly.

## Project roadmap

See [ROADMAP.md](ROADMAP.md) for the phases and their scope.
