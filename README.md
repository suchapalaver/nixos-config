# nixos-config

NixOS configuration for Framework laptop (`nixos-dev`).

## Quick Start

```bash
# Clone to /etc/nixos
sudo git clone https://github.com/suchapalaver/nixos-config.git /etc/nixos
sudo chown -R joseph:users /etc/nixos

# Generate hardware config for this machine
sudo nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix

# Create secrets directory and set password hash
sudo mkdir -p /etc/nixos-secrets
sudo chown joseph:users /etc/nixos-secrets
chmod 700 /etc/nixos-secrets
mkpasswd -m sha-512 | sudo tee /etc/nixos-secrets/joseph-password-hash > /dev/null
chmod 600 /etc/nixos-secrets/joseph-password-hash

# Rebuild
sudo nixos-rebuild switch --flake /etc/nixos#nixos-dev
```

## Structure

| File | Purpose |
|------|---------|
| `flake.nix` | Flake entry point, inputs |
| `configuration.nix` | System packages, services |
| `home.nix` | User packages, shell, dotfiles |
| `hardware-configuration.nix` | Machine-specific hardware (generated) |
| `nvim-config.lua` | Neovim configuration |

## Commands

```bash
# Rebuild system
sudo nixos-rebuild switch --flake /etc/nixos#nixos-dev

# Update inputs
nix flake update /etc/nixos

# Garbage collect
nix-collect-garbage -d
```

## Update Strategy

Treat `nix flake update /etc/nixos` as a broad system input update. It can move
the whole package set and make `nixos-rebuild switch` fetch or build a large
closure. Use it when the goal is a general system refresh.

For a single Nixpkgs-owned package, first check the current locked version:

```bash
nix eval --raw /etc/nixos#nixosConfigurations.nixos-dev.pkgs.trezor-suite.version
```

If the package must move and this repo does not have a dedicated pin for it, use
an input-specific update and expect system-level rebuild impact:

```bash
nix flake update nixpkgs --flake /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos-dev
```

Current policy by tool:

| Tool | Owner | Update path |
|------|-------|-------------|
| Trezor Suite | Nixpkgs `trezor-suite` | Update `nixpkgs`; do not use AppImages or mutable launchers |
| Claude Code | `pins/claude-code.nix` plus `claude-code-nixpkgs` | Run `claude-update` |
| Codex CLI | User npm prefix | Run `codex-update` |

Only add a dedicated pin or overlay for another volatile app when broad Nixpkgs
updates become operationally painful often enough to justify maintaining source
URLs, hashes, and compatibility checks in this repo.

## Contribution Workflow

Use Conventional Commits for commit subjects and PR titles:

```text
chore(nixos): update pinned packages
fix(trezor): manage launcher paths declaratively
docs(codex): document cli ownership
```

Normal changes should go through a pull request against `master`. The repository
uses squash merges and the squash commit title comes from the PR title, so keep
the PR title as the final commit subject you want in history. Direct pushes to
`master` are reserved for emergency recovery.

## Trezor Suite

Trezor Suite is managed by NixOS, not by AppImages in `~/Downloads`.
`configuration.nix` installs `trezor-suite`, adds `trezor-udev-rules`, and enables
`services.trezord`. Home Manager owns compatibility wrappers at
`~/.local/bin/trezor-suite` and `~/bin/trezor`; both delegate to the active system
package at `/run/current-system/sw/bin/trezor-suite`.

Verify the launch path after rebuilding:

```bash
which -a trezor-suite
sed -n '1,3p' "$(which trezor-suite)"
grep '^Exec=' ~/.local/share/applications/trezor-suite.desktop
nix eval --raw /etc/nixos#nixosConfigurations.nixos-dev.pkgs.trezor-suite.version
```

## Codex CLI

Codex CLI is intentionally managed through the user npm prefix, not through
`pkgs.codex` in Home Manager. Home Manager owns `~/.npmrc`, puts
`~/.npm-global/bin` on `PATH`, and defines `codex-update`. This keeps Codex on npm
stable while the locked Nixpkgs package can lag, and avoids two `codex` binaries
competing on `PATH`.

Verify the ownership model:

```bash
which -a codex
npm list --global --depth=0 @openai/codex
nix eval --raw /etc/nixos#nixosConfigurations.nixos-dev.pkgs.codex.version
zsh -ic 'alias codex-update'
```

Switch to Nix only if `pkgs.codex` is current enough, and remove the npm-managed
binary before adding a Nix-managed Codex package.

## Secrets

Password hash stored in `/etc/nixos-secrets/joseph-password-hash` (not in repo).
