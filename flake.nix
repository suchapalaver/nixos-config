{
  description = "NixOS configuration with Home Manager";

  inputs = {
    # Track Brave separately because browser security releases can reach
    # nixpkgs master before the nixos-unstable channel advances.
    brave-nixpkgs.url = "github:NixOS/nixpkgs/master";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, brave-nixpkgs, nixpkgs, home-manager, rust-overlay, sops-nix, ... }: {
    nixosConfigurations.nixos-dev = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            rust-overlay.overlays.default
            (final: _prev: {
              brave = (import brave-nixpkgs {
                inherit (final.stdenv.hostPlatform) system;
                config.allowUnfree = true;
              }).brave;
            })
            (final: prev: {
              # nixpkgs' Rust hook forces system libraries, but foundry's
              # recipe currently omits the ones used by its Rust dependencies.
              foundry = prev.foundry.overrideAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ [
                  final.aws-lc
                  final.rust-jemalloc-sys
                  final.sqlite
                  final.zstd
                ];
              });
              pipx = prev.pipx.overridePythonAttrs (_old: {
                doCheck = false;
              });
            })
          ];
        })

        ./hardware-configuration.nix
        ./configuration.nix

        sops-nix.nixosModules.sops

        home-manager.nixosModules.home-manager
        {
          home-manager.backupFileExtension = "hm-backup";
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.joseph = import ./home.nix;
        }
      ];
    };
  };
}
