{ lib, ... }:

{
  perSystem =
    { pkgs, system, ... }:
    let
      mkAddons = id: lib.imap (mkAddon { owner = id; }) addons;

      idaFhsEnv = pkgs.buildFHSEnv {
        name = "ida-pro-fhs";
        targetPkgs = pkgs: [ pkgs.python3 ];
      };

      libext = pkgs.stdenv.hostPlatform.extensions.sharedLibrary;
    in
    {
      legacyPackages.ida-pro = (mkRawDerivation { }).extend (
        final: _: {
          inherit system;

          name = "ida-pro";
          version = "9.3.260327";

          src = throw "Provide the source yourself, :クルーレス:";

          builder = lib.getExe idaFhsEnv;
          args = [
            "-c"
            /* bash */ ''
              set -xeu pipefail

              cp "$src" 'install.run';
              chmod +x 'install.run';
              ./'install.run' --mode 'unattended' --prefix "$out";
            ''
          ];
        }
      );
    };
}
