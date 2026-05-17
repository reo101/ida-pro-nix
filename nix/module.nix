{ config, inputs, ... }:

{
  imports = [
    inputs.flake-parts.flakeModules.modules
  ];

  flake.modules.homeManager.default = config.flake.modules.homeManager.ida-pro;
  flake.modules.homeManager.ida-pro =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      cfg = config.programs.ida-pro;
      libext = pkgs.stdenv.hostPlatform.extensions.sharedLibrary;
      pythonSharedLibrary = "${cfg.pythonPackage}/lib/lib${cfg.pythonPackage.libPrefix}${libext}";
      pythonPath = "${cfg.pythonPackage}/${cfg.pythonPackage.sitePackages}";

      idaPythonPackageExtension = import ./packages/python-packages-extension.nix;

      extendPython =
        python:
        python.override (old: {
          packageOverrides = lib.foldr lib.composeExtensions (old.packageOverrides or (_: _: { })
          ) cfg.pythonPackageExtensions;
        });

      pluginPythonPackages =
        ps: plugin:
        if lib.isFunction plugin.neededPythonPackages then
          plugin.neededPythonPackages ps
        else if lib.isList plugin.neededPythonPackages then
          lib.map (pkg: if lib.isString pkg then ps.${pkg} else pkg) plugin.neededPythonPackages
        else
          throw "programs.ida-pro.plugins: `${plugin.pname or "<unnamed>"}.neededPythonPackages` must be a function or a list";
    in
    {
      options =
        let
          inherit (lib) types;
          pathLike = types.coercedTo (types.oneOf [
            types.package
            types.path
          ]) lib.toString types.str;
          pluginType = types.submodule {
            # `callPackage` wraps plain attrsets with helper attributes such as
            # `override`/`overrideDerivation`. Keep the plugin schema strict for
            # the fields we consume, but allow those extra callPackage attrs.
            freeformType = types.attrsOf types.raw;
            options = {
              pname = lib.mkOption {
                type = types.str;
              };
              version = lib.mkOption {
                type = types.str;
              };
              src = lib.mkOption {
                type = pathLike;
              };
              neededPythonPackages = lib.mkOption {
                type =
                  types.either
                    # Either a `ps: [ ps.a ps.b ]` ...
                    (types.functionTo (types.listOf types.package))
                    # ... or a direct `[ pkg1 "pkg2" ]`
                    (types.listOf (types.either types.str types.package));
                default = _: [ ];
              };
            };
          };
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
                `hexlic` license file.
              '';
              type = pathLike;
            };
            pythonPackage = lib.mkOption {
              description = ''
                The `python` package used for IDAPython. `withPackages` is applied by the module;
                plugins should expose Python dependencies as `neededPythonPackages = ps: [ ... ]`.
              '';
              type = types.package;
              default = pkgs.python3;
              apply =
                python:
                (extendPython python).withPackages (ps: lib.concatMap (pluginPythonPackages ps) cfg.plugins);
            };
            pythonPackageExtensions = lib.mkOption {
              description = ''
                Python package-set extensions applied before plugin dependencies are resolved.
              '';
              type = types.listOf types.raw;
              default = [ idaPythonPackageExtension ];
            };
            plugins = lib.mkOption {
              description = ''
                Plugins to be installed alongside IDA Pro.
              '';
              type = types.listOf pluginType;
              default = [ ];
            };
          };
        };

      config = lib.mkIf cfg.enable {
        home.packages = [ cfg.package ];

        home.activation.idaProSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] /* bash */ ''
          set -euo pipefail;

          export IDADIR="${cfg.package}";
          export IDAUSR="''${IDAUSR:-$HOME/.idapro}";

          '${lib.getExe' pkgs.coreutils "mkdir"}' -p "$IDAUSR";

          hexlic=${lib.escapeShellArg cfg.hexlic}
          if [ -e "$hexlic" ]; then
            ln -sfnT "$hexlic" "$IDAUSR/idapro.hexlic";
          fi

          '${lib.getExe cfg.pythonPackage}' <<'PY';
          from glob import glob
          import sys

          sys.path.append(glob("${cfg.package}/idalib/python/idapro-*.whl")[0])

          import idapro
          import ida_registry

          # Accept EULA(s)
          ${lib.pipe cfg.eulas [
            (lib.map (eula: /* python */ ''
              ida_registry.reg_write_int("EULA ${lib.toString eula}", 1)
            ''))
            (lib.concatStringsSep "\n")
          ]}

          ida_registry.reg_write_string("Python3TargetDLL", "${pythonSharedLibrary}")
          ida_registry.reg_write_string("Python3ExtraPaths", "${pythonPath}")
          PY

          '${lib.getExe' pkgs.coreutils "mkdir"}' -p "$IDAUSR/plugins";
          ${lib.pipe cfg.plugins [
            (lib.map (plugin: /* bash */ ''
              # Install `${plugin.pname}` plugin (version `${plugin.version}`)
              ln -sfnT ${plugin.src} "$IDAUSR/plugins/${plugin.pname}";
            ''))
            (lib.concatStringsSep "\n")
          ]}
        '';
      };
    };

  # HACK: why isn't this the default
  flake.homeManagerModules = config.flake.modules.homeManager;
}
