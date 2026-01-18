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

## Secrets

Password hash stored in `/etc/nixos-secrets/joseph-password-hash` (not in repo).
