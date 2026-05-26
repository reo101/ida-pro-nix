{
  lib,
  pkgs,
  ida-pro,
  extensions ? [ ],
}:

let
  baseScope = lib.makeScope pkgs.newScope (self: {
    inherit ida-pro;

    diaphora = self.callPackage ./diaphora.nix { };
    hrtng = self.callPackage ./hrtng.nix { };
    ida-cyberchef = self.callPackage ./ida-cyberchef.nix { };
    openlumina = self.callPackage ./openlumina.nix { };
    ponce = self.callPackage ./ponce.nix { };
    tenet = self.callPackage ./tenet.nix { };
  });
in
lib.foldl' (scope: extension: scope.overrideScope extension) baseScope extensions
