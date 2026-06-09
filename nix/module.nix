{ config, inputs, ... }:

let
  flakeConfig = config;
in
{
  imports = [
    inputs.flake-parts.flakeModules.modules
  ];

  flake.modules.homeManager.default = flakeConfig.flake.modules.homeManager.ida-pro;
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

      pluginBaseScope =
        flakeConfig.flake.legacyPackages.${pkgs.stdenv.hostPlatform.system}.idaPlugins;

      pluginsScope =
        lib.foldl' (scope: extension: scope.overrideScope extension)
          pluginBaseScope
          cfg.pluginPackageExtensions;

      extendPython =
        python:
        python.override (old: {
          packageOverrides = lib.foldr lib.composeExtensions (old.packageOverrides or (_: _: { })
          ) cfg.pythonPackageExtensions;
        });

      resolvePythonPackages =
        optionName: ps: packages:
        if lib.isFunction packages then
          packages ps
        else if lib.isList packages then
          lib.map (pkg: if lib.isString pkg then ps.${pkg} else pkg) packages
        else
          throw "${optionName} must be a function or a list";

      pluginPythonPackages =
        ps: plugin:
        resolvePythonPackages
          "programs.ida-pro.plugins: `${plugin.pname or "<unnamed>"}.neededPythonPackages`"
          ps
          plugin.neededPythonPackages;

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

      selectedTheme =
        if cfg.themeFile != null then
          directThemeName
        else if cfg.theme != null then
          cfg.theme
        else
          "default";

      stylixEnabled =
        options ? stylix.enable
        && config.stylix.enable
        && config.stylix.targets.ida-pro.enable
        && config ? lib.stylix.colors;

      stylixCss = import ./themes/stylix.nix { colors = config.lib.stylix.colors; };

      registrySettingsDefaults = {
        Python3TargetDLL = pythonSharedLibrary;
        Python3ExtraSitePaths = pythonSitePath;
        Python3ExtraBinPaths = pluginBinPath;
        ThemeName = selectedTheme;
      }
      // lib.listToAttrs (lib.map (eula: lib.nameValuePair "EULA ${lib.toString eula}" 1) cfg.eulas);

      showSettingPath =
        optionLoc: path:
        lib.concatStringsSep "." optionLoc + lib.concatMapStrings (name: "[${builtins.toJSON name}]") path;

      parseRegistrySettings =
        optionLoc: path: settings:
        lib.mapAttrs (name: parseRegistryValue optionLoc (path ++ [ name ])) settings;

      parseRegistryValue =
        optionLoc: path: value:
        if builtins.isAttrs value then
          {
            shape = "subkey";
            value = parseRegistrySettings optionLoc path value;
          }
        else if builtins.isList value then
          if builtins.all builtins.isString value then
            {
              shape = "string-list";
              value = value;
            }
          else if builtins.all builtins.isInt value then
            let
              invalidByte = lib.findFirst (item: !(0 <= item && item <= 255)) null value;
            in
            if invalidByte == null then
              {
                shape = "binary";
                value = value;
              }
            else
              throw "${showSettingPath optionLoc path}: integer lists are written as binary data, but ${lib.toString invalidByte} is outside the byte range 0..255"
          else
            throw "${showSettingPath optionLoc path}: lists must contain either only strings or only byte integers"
        else if builtins.isString value then
          {
            shape = "string";
            inherit value;
          }
        else if builtins.isInt value then
          {
            shape = "int";
            inherit value;
          }
        else if builtins.isBool value then
          {
            shape = "bool";
            inherit value;
          }
        else if builtins.typeOf value == "null" then
          {
            shape = "delete";
            inherit value;
          }
        else
          throw "${showSettingPath optionLoc path}: unsupported IDA registry setting value of type ${builtins.typeOf value}";
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
          pythonPackagesSpecType =
            types.either
              # Either a `ps: [ ps.a ps.b ]` ...
              (types.functionTo (types.listOf types.package))
              # ... or a direct `[ pkg1 "pkg2" ]`.
              (types.listOf (types.either types.str types.package));
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
                type = pythonPackagesSpecType;
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
                (extendPython python).withPackages (
                  ps:
                  resolvePythonPackages "programs.ida-pro.extraPythonPackages" ps cfg.extraPythonPackages
                  ++ lib.concatMap (pluginPythonPackages ps) cfg.plugins
                );
            };
            extraPythonPackages = lib.mkOption {
              description = ''
                Additional Python packages to make available to IDAPython.
                The value can be a function like `python.withPackages`, or a
                direct list containing package values and package names from the
                final Python package set.
              '';
              type = pythonPackagesSpecType;
              default = _: [ ];
              example = lib.literalExpression ''
                ps: [
                  ps.requests
                  "pydantic"
                ]
              '';
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
                They are layered with `overrideScope` on top of the exported
                `legacyPackages.''${system}.idaPlugins` scope.

                The scope exposes `ida-pro-version`, bound to
                `programs.ida-pro.package.version`, and `ida-sdk`, bound to the
                matching IDA SDK source. This lets plugin definitions depend on
                the selected IDA version and SDK without depending on the IDA Pro
                derivation. `allPlugins` is computed from plugin-shaped scope
                attributes.
              '';
              type = types.listOf types.raw;
              default = [ ];
              apply =
                extensions:
                [ (_final: _prev: { ida-pro-version = cfg.package.version; }) ]
                ++ extensions;
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
                plugin package set derived from `legacyPackages.''${system}.idaPlugins`.

                The package set is extensible through
                `programs.ida-pro.pluginPackageExtensions` and exposes
                `ida-pro-version` as the selected `programs.ida-pro.package.version`
                plus `ida-sdk` as the matching SDK source.
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
              apply =
                themes:
                lib.optionalAttrs stylixEnabled {
                  stylix = {
                    imports = [ "dark" ];
                    source = null;
                    text = stylixCss;
                  };
                }
                // themes;
              example = lib.literalExpression ''
                {
                  my-theme.text = '''
                    CustomIDAMemo {
                      qproperty-line-bg-default: #1e1e2e;
                    }
                  ''';
                  dark.source = inputs.ida-pro.legacyPackages.''${pkgs.stdenv.hostPlatform.system}.themes.dark.source;
                }
              '';
            };
            theme = lib.mkOption {
              description = ''
                Name of the IDA theme to select. When neither `theme` nor
                `themeFile` is set, the built-in `default` theme is selected.
              '';
              type = types.nullOr types.str;
              default = if stylixEnabled && cfg.themeFile == null then "stylix" else null;
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
            settings = lib.mkOption {
              description = ''
                Declarative IDA registry settings. Attribute sets become
                registry subkeys and scalar values become values in the current
                key. Strings, integers, booleans and null are supported; null
                deletes the named value. A list of strings is written as an IDA
                string-list key, while a list of integers in the range 0..255 is
                written as a binary value.

                The module populates this option with defaults for IDAPython,
                plugin paths, selected theme, and accepted EULAs. User values
                can override those defaults with normal module priorities.
              '';
              type = types.attrsOf types.anything;
              default = { };
              apply = lib.recursiveUpdate (lib.optionalAttrs cfg.enable registrySettingsDefaults);
              example = lib.literalExpression ''
                {
                  ThemeName = "dark";
                  "EULA 93" = 1;
                  MyPlugin = {
                    Enabled = true;
                    CachePath = "/tmp/ida-cache";
                  };
                }
              '';
            };
            registrySettingsJson = lib.mkOption {
              description = ''
                Read-only parsed IDA registry settings as JSON. This is the
                representation consumed by the activation script: each setting is
                tagged with a `shape` and a `value` after Nix-side parsing and
                validation.
              '';
              type = types.str;
              readOnly = true;
              default = lib.pipe cfg.settings [
                (parseRegistrySettings [ "programs" "ida-pro" "settings" ] [ ])
                builtins.toJSON
              ];
            };
          };
        };

      config = lib.mkIf cfg.enable {
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
          import json
          import sys

          sys.path.append(glob("${cfg.package}/idalib/python/idapro-*.whl")[0])

          import idapro
          import ida_registry

          with open(${builtins.toJSON (toString (pkgs.writeText "ida_registry_settings.json" cfg.registrySettingsJson))}) as registry_settings_file:
              registry_settings = json.load(registry_settings_file)

          def registry_path(parts):
              return "/".join(parts) if parts else None

          def write_registry_value(name, entry, parts):
              subkey = registry_path(parts)

              match entry:
                  case {"shape": "subkey", "value": value}:
                      write_registry_tree(value, (*parts, name))
                  case {"shape": "delete"}:
                      ida_registry.reg_delete(name, subkey)
                  case {"shape": "bool", "value": value}:
                      ida_registry.reg_write_bool(name, int(value), subkey)
                  case {"shape": "int", "value": value}:
                      ida_registry.reg_write_int(name, value, subkey)
                  case {"shape": "string", "value": value}:
                      ida_registry.reg_write_string(name, value, subkey)
                  case {"shape": "string-list", "value": value}:
                      ida_registry._ida_registry.reg_write_strlist(value, registry_path([*parts, name]))
                  case {"shape": "binary", "value": value}:
                      ida_registry.reg_write_binary(name, bytes(value), subkey)
                  case {"shape": shape}:
                      raise ValueError(f"unknown registry setting shape {shape!r}")
                  case _:
                      raise ValueError(f"invalid registry setting entry {entry!r}")

          def write_registry_tree(settings, parts=()):
              for name, entry in settings.items():
                  write_registry_value(name, entry, parts)

          write_registry_tree(registry_settings)
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
