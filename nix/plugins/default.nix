{ lib, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs) lib;

      scopeAttrs = scope: builtins.removeAttrs scope [
        "callPackage"
        "newScope"
        "overrideScope"
        "packages"
      ];

      pluginsScope = lib.makeScope pkgs.newScope (self: {
        diaphora = self.callPackage ./diaphora.nix { };
        hrtng = self.callPackage ./hrtng.nix { };
        ida-cyberchef = self.callPackage ./ida-cyberchef.nix { };
        ponce = self.callPackage ./ponce.nix { };
        tenet = self.callPackage ./tenet.nix { };
      });
    in
    {
      legacyPackages = {
        plugins = scopeAttrs pluginsScope;
        pluginsScope = pluginsScope;
        pluginsWith = overrides: scopeAttrs (pluginsScope.overrideScope overrides);
      };
    };
}
