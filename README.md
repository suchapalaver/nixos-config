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

## Secrets

Password hash stored in `/etc/nixos-secrets/joseph-password-hash` (not in repo).
