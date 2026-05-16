{
  perSystem = { pkgs, ... }: {
    legacyPackages.plugins = {
      ida-cyberchef = pkgs.callPackage ./ida-cyberchef.nix { };
    };
  };
}
