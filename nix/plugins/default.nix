{ lib, ... }:

{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      mkIdaPlugins =
        {
          ida-pro-version,
          extensions ? [ ],
        }:
        let
          pythonPackages = pkgs.python3Packages;

          importPackages =
            scope: dir: ignored:
            let
              entries = builtins.readDir dir;
              isPackage =
                name: type:
                !builtins.elem name ignored
                && (type == "directory" || (type == "regular" && lib.hasSuffix ".nix" name));
            in
            lib.mapAttrs' (
              name: _: lib.nameValuePair (lib.removeSuffix ".nix" name) (scope.callPackage (dir + "/${name}") { })
            ) (lib.filterAttrs isPackage entries);

          baseScope = lib.makeScope pkgs.newScope (
            self:
            importPackages self ./. [ "default.nix" ]
            // {
              inherit ida-pro-version pythonPackages;

              ida-sdk = pkgs.fetchFromGitHub {
                owner = "HexRaysSA";
                repo = "ida-sdk";
                rev = "v${lib.versions.pad 2 self.ida-pro-version}.1-release";
                hash = "sha256-on7EDh0bwnhordMN9AoIGFdQWCzPtwcOagvmcWBtjkk=";
              };
            }
          );

          extendedScope = lib.foldl' (scope: extension: scope.overrideScope extension) baseScope extensions;

          nonPluginAttrs = [
            "allPlugins"
            "callPackage"
            "ida-pro-version"
            "ida-sdk"
            "newScope"
            "overrideScope"
            "packages"
          ];

          pluginCandidates = scope: builtins.removeAttrs scope nonPluginAttrs;
          isPlugin = value: lib.isAttrs value && value ? pname && value ? version && value ? drv;
          isPluginSupported = plugin: lib.meta.availableOn pkgs.stdenv.hostPlatform plugin;
          pluginAttrs =
            scope:
            lib.filterAttrs (_: value: isPlugin value && isPluginSupported value) (pluginCandidates scope);
          unsupportedPluginNames =
            scope:
            lib.attrNames (
              lib.filterAttrs (_: value: isPlugin value && !isPluginSupported value) (pluginCandidates scope)
            );

          scopeWithAllPlugins = extendedScope.overrideScope (
            final: prev: {
              allPlugins = lib.attrValues (pluginAttrs final);
            }
          );
        in
        builtins.removeAttrs scopeWithAllPlugins (unsupportedPluginNames scopeWithAllPlugins);
    in
    {
      legacyPackages = {
        idaPlugins = mkIdaPlugins {
          inherit (config.legacyPackages.supported) ida-pro-version;
        };

        ida-sdk = config.legacyPackages.idaPlugins.ida-sdk;
      };
    };
}
