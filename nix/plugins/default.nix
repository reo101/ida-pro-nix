{
  perSystem =
    { pkgs, ... }:
    {
      legacyPackages.plugins = {
        diaphora = pkgs.callPackage ./diaphora.nix { };
        hrtng = pkgs.callPackage ./hrtng.nix { };
        ida-cyberchef = pkgs.callPackage ./ida-cyberchef.nix { };
        ponce = pkgs.callPackage ./ponce.nix { };
        tenet = pkgs.callPackage ./tenet.nix { };
      };
    };
}
