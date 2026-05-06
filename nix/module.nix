{ config, lib, ... }:

{
  flake.modules.nixos.default = config.flake.modules.nixos.ida-pro;
  flake.modules.nixos.ida-pro =
    {
      pkgs,
      system,
      config,
      ...
    }:
    let
      cfg = config.programs.ida-pro;
      libext = pkgs.stdenv.hostPlatform.extensions.sharedLibrary;
      pythonSharedLibrary = "${cfg.pythonPackage}/lib/lib${cfg.pythonPackage.libPrefix}${libext}";
    in
    {
      options =
        let
          inherit (lib) types;
          pathLike = types.coercedTo (types.oneOf [
            types.package
            types.path
          ]) builtins.toString types.str;
        in
        {
          programs.ida-pro = {
            enable = lib.mkEnableOption "IDA Pro";
            package = lib.mkOption {
              description = ''
                Base (nixified) package for IDA Pro. Best aquired by doing:

                ```
                inputs.ida-pro.packages.''${system}.ida-pro.override {
                  src = ...;
                }
                ```
              '';
              type = types.package;
            };
            eulas = lib.mkOption {
              description = ''
                Which versions of the [Hex-Rays EULA](https://hex-rays.com/eula) you agree to.
              '';
              type = types.listOf (lib.types.enum (lib.range 90 94));
              default = [ ];
            };
            hexlic = lib.mkOption {
              description = ''
                Path to a `hexlic` license file.
              '';
              type = pathLike;
            };
            pythonPackage = lib.mkOption {
              description = ''
                The `python` package used for `idapyswitch`.
              '';
              type = types.package;
              default = pkgs.python3;
            };
            # TODO: under construction
            plugins = lib.mkOption {
              description = ''
                Plugins to be installed alongside IDA Pro.
              '';
              type = types.listOf (types.enum [ ]);
              default = [ ];
            };
          };
        };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ cfg.package ];

        # TODO: configurable `configDir`
        system.userActivationScripts.idaProSetup = {
          text = /* bash */ ''
            set -euo pipefail

            export IDADIR="${cfg.package}"
            export IDAUSR="$HOME/.idapro"
            '${lib.getExe' pkgs.coreutils "mkdir"}' -p "$IDAUSR"

            hexlic=${lib.escapeShellArg cfg.hexlic}
            if [ -e "$hexlic" ]; then
              '${lib.getExe' pkgs.coreutils "install"}' -m 0600 \
                "$hexlic" \
                "$IDAUSR/idapro.hexlic"
            fi

            '${lib.getExe cfg.pythonPackage}' <<'PY'
            from __future__ import annotations

            import os
            import sys
            from pathlib import Path

            idadir = Path(os.environ.get("IDADIR"))
            idausr = Path(os.environ.get("IDAUSR"))

            os.environ.setdefault("TVHEADLESS", "1")

            wheels = sorted((idadir / "idalib" / "python").glob("idapro-*.whl"))
            paths = [*(str(w) for w in wheels), str(idadir / "idalib" / "python"), str(idadir / "python")]
            sys.path[:0] = [path for path in paths if path not in sys.path]

            import idapro  # noqa: F401
            import ida_registry

            ${lib.pipe cfg.eulas [
              (lib.map (eula: /* python */ ''ida_registry.reg_write_int("EULA${builtins.toString eula}", 1)''))
              (lib.concatStringsSep "\n")
            ]}

            ida_registry.reg_write_string("Python3TargetDLL", "${pythonSharedLibrary}")
            PY
          '';
        };
      };
    };
}
