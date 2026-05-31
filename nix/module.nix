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
      options,
      ...
    }:
    let
      cfg = config.programs.ida-pro;
      libext = pkgs.stdenv.hostPlatform.extensions.sharedLibrary;
      pythonSharedLibrary = "${cfg.pythonPackage}/lib/lib${cfg.pythonPackage.libPrefix}${libext}";
      pythonSitePath = "${cfg.pythonPackage}/${cfg.pythonPackage.sitePackages}";

      idaPythonPackageExtension = import ./packages/python-packages-extension.nix;

      pluginsScope = import ./plugins {
        inherit lib pkgs;
        ida-pro = cfg.package;
        extensions = cfg.pluginPackageExtensions;
      };

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

      pluginPackages =
        plugin:
        let
          packages = plugin.packages or (lib.optional (plugin ? package) plugin.package);
        in
        if lib.isFunction packages then
          packages {
            inherit pkgs lib;
            ida-pro = cfg.package;
            pythonPackage = cfg.pythonPackage;
          }
        else
          packages;

      pluginBinPath = lib.makeBinPath (lib.concatMap pluginPackages cfg.plugins);

      themeImportsCss =
        theme:
        lib.concatMapStrings (importName: /* css */ ''
          @importtheme ${builtins.toJSON importName};
        '') theme.imports;

      themeFile =
        name: theme:
        let
          importsCss = themeImportsCss theme;
        in
        if theme.source != null && theme.imports == [ ] then
          theme.source
        else if theme.source != null then
          pkgs.runCommand "ida-pro-${name}-theme.css" { } ''
            cat ${pkgs.writeText "ida-pro-${name}-theme-imports.css" importsCss} > "$out"
            cat ${lib.escapeShellArg (toString theme.source)} >> "$out"
          ''
        else
          pkgs.writeText "ida-pro-${name}-theme.css" (importsCss + theme.text);

      directThemeName = "home-manager";

      directTheme = lib.optionalAttrs (cfg.themeFile != null) {
        ${directThemeName} = {
          imports = cfg.themeFileImports;
          source = cfg.themeFile;
        };
      };

      themes = cfg.themes // directTheme;

      themeFiles = lib.mapAttrs themeFile themes;

      selectedTheme = if cfg.themeFile != null then directThemeName else cfg.theme or "default";

      stylixEnabled =
        options ? stylix.enable
        && config.stylix.enable
        && config.stylix.targets.ida-pro.enable
        && config ? lib.stylix.colors;

      stylixCss = import ./themes/stylix.nix { colors = config.lib.stylix.colors; };
    in
    {
      options =
        let
          inherit (lib) types;
          pathLike = types.coercedTo (types.oneOf [
            types.package
            types.path
          ]) lib.toString types.str;
          themeType =
            types.coercedTo types.path
              (source: {
                source = lib.toString source;
                imports = [ ];
              })
              (
                types.coercedTo types.lines (text: { inherit text; }) (
                  types.submodule {
                    freeformType = types.attrsOf types.raw;
                    options = {
                      imports = lib.mkOption {
                        type = types.listOf types.str;
                        default = [ "dark" ];
                        description = ''
                          IDA themes to import before this theme's CSS. This is
                          useful for partial themes: by default inline custom CSS is
                          layered over IDA's complete `dark` theme instead of
                          falling back to light/default qproperty colors.
                        '';
                      };
                      source = lib.mkOption {
                        type = types.nullOr pathLike;
                        default = null;
                        description = ''
                          Path to a CSS file to install as this IDA theme's `theme.css`.
                        '';
                      };
                      text = lib.mkOption {
                        type = types.nullOr types.lines;
                        default = null;
                        description = ''
                          CSS text to install as this IDA theme's `theme.css`.
                        '';
                      };
                    };
                  }
                )
              );
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
              drv = lib.mkOption {
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
          stylix.targets.ida-pro.enable = lib.mkOption {
            description = ''
              Whether Stylix should generate and select an IDA Pro CSS theme.
            '';
            type = types.bool;
            default = config.stylix.autoEnable or true;
            defaultText = lib.literalExpression "config.stylix.autoEnable";
            example = false;
          };

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
            pluginPackageExtensions = lib.mkOption {
              description = ''
                Extensions applied to the IDA plugin package set passed to
                `programs.ida-pro.plugins`. Extension functions receive the
                final and previous plugin scopes and may use `final.callPackage`.

                The scope exposes `ida-pro`, bound to
                `programs.ida-pro.package`, so plugin definitions can depend on
                the selected IDA Pro package. `allPlugins` is computed from
                plugin-shaped scope attributes.
              '';
              type = types.listOf types.raw;
              default = [ ];
              example = lib.literalExpression ''
                [
                  (final: prev: {
                    my-plugin = final.callPackage ./my-plugin.nix { };
                  })
                ]
              '';
            };
            plugins = lib.mkOption {
              description = ''
                Plugins to be installed alongside IDA Pro. The value is a
                function, like `python.withPackages`, that receives the IDA
                plugin package set.

                The package set is extensible through
                `programs.ida-pro.pluginPackageExtensions` and exposes
                `ida-pro` as the selected `programs.ida-pro.package`.
              '';
              type = types.functionTo (types.listOf pluginType);
              default = _: [ ];
              apply = plugins: plugins pluginsScope;
              example = lib.literalExpression ''
                ps: [
                  ps.diaphora
                  ps.ida-cyberchef
                ]
              '';
            };
            themes = lib.mkOption {
              description = ''
                Declarative IDA CSS themes. Each attribute is installed as
                `$IDAUSR/themes/<name>/theme.css` and can either provide
                `source = ./theme.css` or inline `text = ''${...}` CSS.
                Inline/custom themes import IDA's `dark` theme by default;
                set `imports = [ ];` for a complete standalone theme.
              '';
              type = types.attrsOf themeType;
              default = { };
              example = lib.literalExpression ''
                {
                  my-theme.text = ''''
                    CustomIDAMemo {
                      qproperty-line-bg-default: #1e1e2e;
                    }
                  '''';
                  dark.source = inputs.ida-pro.legacyPackages.''${pkgs.system}.themes.dark.source;
                }
              '';
            };
            theme = lib.mkOption {
              description = ''
                Name of the IDA theme to select. When neither `theme` nor
                `themeFile` is set, the built-in `default` theme is selected.
              '';
              type = types.nullOr types.str;
              default = null;
              example = "dark";
            };
            themeFile = lib.mkOption {
              description = ''
                CSS file, path, or derivation to install directly as the
                selected IDA theme. This is a shortcut for defining a theme in
                `programs.ida-pro.themes`; it is installed under the reserved
                theme name `home-manager`.
              '';
              type = types.nullOr pathLike;
              default = null;
              example = lib.literalExpression "./ida-theme.css";
            };
            themeFileImports = lib.mkOption {
              description = ''
                IDA themes to import before `themeFile`. Defaults to `dark` so
                small custom CSS files do not fall back to IDA's incomplete
                light/default qproperty palette. Set to `[ ]` for a complete
                standalone CSS theme file.
              '';
              type = types.listOf types.str;
              default = [ "dark" ];
            };
          };
        };

      config = lib.mkIf cfg.enable {
        programs.ida-pro.themes = lib.mkIf stylixEnabled {
          stylix = {
            imports = [ "dark" ];
            text = stylixCss;
          };
        };

        programs.ida-pro.theme = lib.mkIf (stylixEnabled && cfg.themeFile == null) (lib.mkDefault "stylix");

        assertions = [
          {
            assertion = cfg.theme == null || cfg.themeFile == null;
            message = "programs.ida-pro: set either `theme` or `themeFile`, not both";
          }
          {
            assertion = !(builtins.hasAttr directThemeName cfg.themes && cfg.themeFile != null);
            message = "programs.ida-pro.themes.${directThemeName}: reserved for `programs.ida-pro.themeFile`";
          }
        ]
        ++ lib.flatten (
          lib.mapAttrsToList (name: theme: [
            {
              assertion = !(lib.hasInfix "/" name);
              message = "programs.ida-pro.themes: theme name `${name}` must not contain `/`";
            }
            {
              assertion = builtins.all (importName: !(lib.hasInfix "/" importName)) theme.imports;
              message = "programs.ida-pro.themes.${name}.imports: imported theme names must not contain `/`";
            }
            {
              assertion = (theme.source != null) != (theme.text != null);
              message = "programs.ida-pro.themes.${name}: set exactly one of `source` or `text`";
            }
          ]) themes
        );

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
          ida_registry.reg_write_string("Python3ExtraSitePaths", "${pythonSitePath}")
          ida_registry.reg_write_string("Python3ExtraBinPaths", "${pluginBinPath}")
          ida_registry.reg_write_string("ThemeName", ${builtins.toJSON selectedTheme})
          PY

          '${lib.getExe' pkgs.coreutils "mkdir"}' -p "$IDAUSR/plugins";
          ${lib.pipe cfg.plugins [
            (lib.map (plugin: /* bash */ ''
              # Install `${plugin.pname}` plugin (version `${plugin.version}`)
              ln -sfnT ${plugin.drv} "$IDAUSR/plugins/${plugin.installName or plugin.pname}";
            ''))
            (lib.concatStringsSep "\n")
          ]}

          '${lib.getExe' pkgs.coreutils "mkdir"}' -p "$IDAUSR/themes";
          ${lib.pipe themeFiles [
            (lib.mapAttrsToList (
              name: file: /* bash */ ''
                # Install `${name}` theme
                theme_name=${lib.escapeShellArg name};
                theme_dir="$IDAUSR/themes/$theme_name";
                '${lib.getExe' pkgs.coreutils "mkdir"}' -p "$theme_dir";
                ln -sfnT ${lib.escapeShellArg (toString file)} "$theme_dir/theme.css";
              ''
            ))
            (lib.concatStringsSep "\n")
          ]}
        '';
      };
    };

  # HACK: why isn't this the default
  flake.homeManagerModules = config.flake.modules.homeManager;
}
