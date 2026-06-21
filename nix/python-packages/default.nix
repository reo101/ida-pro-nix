{
  flake.overlays.default = final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (import ./extension.nix { inherit (final) lib; })
    ];
  };
}
