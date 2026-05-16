{
  flake.overlays.default = final: prev: {
    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (import ./python-packages-extension.nix)
    ];
  };
}
