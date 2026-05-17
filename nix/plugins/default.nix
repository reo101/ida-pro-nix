{
  perSystem = { pkgs, ... }: {
    legacyPackages.plugins = {
      hrtng = pkgs.callPackage ./hrtng.nix { };
      ida-cyberchef = pkgs.callPackage ./ida-cyberchef.nix { };
    };
  };
}
