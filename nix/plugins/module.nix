{ lib, ... }:

{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    {
      legacyPackages = {
        idaPlugins = import ./. {
          inherit lib pkgs;
          inherit (config.legacyPackages.supported) ida-pro-version;
        };

        ida-sdk = config.legacyPackages.idaPlugins.ida-sdk;
      };
    };
}
