{
  lib,
  pkgs,
  ida-pro-version,
  extensions ? [ ],
}:

let
  baseScope = lib.makeScope pkgs.newScope (self: {
    inherit ida-pro-version;

    ida-sdk = pkgs.fetchFromGitHub {
      owner = "HexRaysSA";
      repo = "ida-sdk";
      rev = "v${lib.versions.pad 2 self.ida-pro-version}.1-release";
      hash = "sha256-on7EDh0bwnhordMN9AoIGFdQWCzPtwcOagvmcWBtjkk=";
    };

    diaphora = self.callPackage ./diaphora.nix { };
    hrtng = self.callPackage ./hrtng.nix { };
    ida-cyberchef = self.callPackage ./ida-cyberchef.nix { };
    openlumina = self.callPackage ./openlumina.nix { };
    ponce = self.callPackage ./ponce.nix { };
    tenet = self.callPackage ./tenet.nix { };
  });

  extendedScope = lib.foldl' (scope: extension: scope.overrideScope extension) baseScope extensions;

  pluginAttrs =
    scope:
    lib.filterAttrs (
      _: value:
      lib.isAttrs value && value ? pname && value ? version && value ? drv
    ) (builtins.removeAttrs scope [
      "allPlugins"
      "callPackage"
      "ida-pro-version"
      "ida-sdk"
      "newScope"
      "overrideScope"
      "packages"
    ]);
in
extendedScope.overrideScope (final: prev: {
  allPlugins = lib.attrValues (pluginAttrs final);
})
