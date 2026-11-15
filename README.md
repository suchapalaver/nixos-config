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

# Install the configuration for the next boot, then reboot
sudo nixos-rebuild boot --flake /etc/nixos#nixos-dev
sudo reboot
```

## Structure

| File | Purpose |
|------|---------|
| `flake.nix` | Flake entry point, inputs |
| `configuration.nix` | System packages, services |
| `home.nix` | User packages, shell, dotfiles |
| `hardware-configuration.nix` | Machine-specific hardware (generated) |
| `nvim-config.lua` | Neovim configuration |
| `nixos-update.sh` | Guarded update, publication, and activation workflow |

## Commands

```bash
# Prepare and validate a coordinated system update
update

# Commit, push, and open the validated update PR
update-publish

# After reviewing and merging the PR, install clean master for the next boot
rebuild
sudo reboot

# Inspect Git, generation, firmware, and service state
nixos-status
```

## Update Strategy

Updates are staged through `nixos-update`; they are never activated from a dirty
tree and broad updates never use live `switch`. Run a coordinated system update
every 2-4 weeks:

```bash
update                  # prepare system: branch, update, check, and build
update-publish          # commit flake.lock, push, and open a PR
# Review and squash-merge the PR.
rebuild                 # fast-forward clean master and run nixos-rebuild boot
sudo reboot
```

`update` refreshes `nixpkgs`, Home Manager, `rust-overlay`, and `sops-nix`.
The expected dirty state exists only on the temporary update branch between
`update` and `update-publish`. Use `update-cancel` to abandon that lockfile-only
update safely. `rebuild` refuses to run unless `master` is clean and matches the
remote after a fast-forward.

Brave follows the fast-moving Nixpkgs `master` branch so browser security fixes
can arrive before `nixos-unstable`. Update it separately, at most weekly or when
a relevant Brave security release is available:

```bash
update-brave
update-publish
# Review and merge the PR, then run `rebuild` and reboot.
```

The validation build intentionally happens before the lockfile is committed.
The helper suppresses the otherwise expected dirty-tree warning only for those
validation commands. Activation always happens from committed, clean `master`.

### What each stage means in NixOS

1. **Update inputs:** `nix flake update` changes `flake.lock`, the exact graph of
   upstream revisions and hashes. It does not update the running machine.
2. **Evaluate and build:** `nix flake check` evaluates declared checks, and
   `nix build` realises the complete system closure in `/nix/store`. Neither
   command activates it.
3. **Record the declaration:** committing the lockfile makes the tested closure
   reproducible and reviewable. The PR is the boundary between a candidate and
   the configuration trusted for activation.
4. **Create a generation:** `nixos-rebuild boot` builds from clean `master`,
   advances the system profile, and installs a boot entry. It deliberately does
   not replace services or libraries in the running desktop.
5. **Reboot and verify:** rebooting starts the new immutable generation. Until
   then, `/run/current-system` identifies the old running generation while
   `/nix/var/nix/profiles/system` identifies the next boot default.

Previous generations remain selectable in the systemd-boot menu, which is the
normal rollback path if a new generation fails. This is why garbage collection
is kept separate from updating.

For a single Nixpkgs-owned package, first check the current locked version:

```bash
nix eval --raw /etc/nixos#nixosConfigurations.nixos-dev.pkgs.trezor-suite.version
```

If a Nixpkgs-owned package must move, use the normal `update` flow because moving
`nixpkgs` can affect the entire system closure, even when only one package
motivated the update. The underlying manual operations performed by the helper
are:

```bash
nix flake update nixpkgs --flake /etc/nixos
nix flake check /etc/nixos
nix build --no-link /etc/nixos#nixosConfigurations.nixos-dev.config.system.build.toplevel
```

Current policy by tool:

| Tool | Owner | Update path |
|------|-------|-------------|
| Trezor Suite | Nixpkgs `trezor-suite` | Update `nixpkgs`; do not use AppImages or mutable launchers |
| Brave | `brave-nixpkgs` input | Run `update-brave`, then `update-publish`; merge and activate with `rebuild` |
| Codex CLI | User npm prefix | Run `codex-update` |

Only add a dedicated pin or overlay for another volatile app when broad Nixpkgs
updates become operationally painful often enough to justify maintaining source
URLs, hashes, and compatibility checks in this repo.

Do not run automatic garbage collection as part of an update. First confirm the
new generation is stable and retain recent rollback generations. Review them
manually with:

```bash
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

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
