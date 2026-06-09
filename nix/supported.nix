let
  supported = {
    ida-pro-version = "9.3.260327";
  };
in

{
  flake.supported = supported;

  perSystem = { ... }: {
    legacyPackages.supported = supported;
  };
}
