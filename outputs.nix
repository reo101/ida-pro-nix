inputs:
inputs.flake-parts.lib.mkFlake { inherit inputs; } (
  {
    withSystem,
    flake-parts-lib,
    lib,
    config,
    ...
  }:
  {
    systems = import inputs.systems.outPath;

    imports = [
      inputs.flake-file.flakeModules.default
      ./nix/ida-pro.nix
      ./nix/module.nix
      ./nix/python-packages
      ./nix/plugins
      ./nix/supported.nix
      ./nix/themes
    ];

    flake-file = {
      nixConfig = {
        commit-lockfile-summary = "chore(flake): update `flake.lock`";
        extra-experimental-features = [
          "pipe-operators"
        ];
      };

      inputs = {
        systems = {
          url = "github:nix-systems/default";
        };

        nixpkgs = {
          url = "github:nixos/nixpkgs/nixos-unstable";
        };

        flake-file = {
          url = "github:vic/flake-file";
        };

        flake-parts = {
          url = "github:hercules-ci/flake-parts";
          inputs.nixpkgs-lib.follows = "nixpkgs";
        };
      };
    };

    perSystem =
      { pkgs, system, ... }:
      {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
          };
          overlays = [ config.flake.overlays.default ];
        };

        formatter = pkgs.nixfmt;
      };
  }
)
