{
  description = "NixOS configuration with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
    sops-nix.url = "github:Mic92/sops-nix";
    claude-code-nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, home-manager, rust-overlay, sops-nix, claude-code-nixpkgs, ... }: {
    nixosConfigurations.nixos-dev = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [
            rust-overlay.overlays.default
            (import ./overlays/claude-code.nix { inherit claude-code-nixpkgs; })
            (final: prev: {
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
