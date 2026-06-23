{ lib, ... }:

{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      patchelfRpaths = lib.makeSearchPathOutput "lib" "lib" [
        pkgs.openssl
      ];

      hexVaultFhs = pkgs.buildFHSEnv { name = "hex-vault-fhs"; };

      hexvault = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "hexvault";
        version = "2.0";

        src = throw "Provide the source yourself, :クルーレス:";

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
          pkgs.patchelf
        ];

        buildInputs = [
          pkgs.stdenv.cc.cc
        ];

        appendRunpaths = patchelfRpaths;

        dontConfigure = true;
        dontBuild = true;

        unpackPhase = ''
          runHook preUnpack

          ${lib.getExe hexVaultFhs} -c ${
            lib.escapeShellArg (/* bash */ ''
              set -xeuo pipefail;

              cp "$src" 'install.run';
              chmod +x 'install.run';
              ./'install.run' --mode 'unattended' --prefix "$PWD/hexvault" \
                --initialization 0 --service 0;
            '')
          }

          sourceRoot="$PWD/hexvault"

          runHook postUnpack
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p "$out";

          mkdir -p "$out/bin";
          mv ./vault_server "$out/bin/";

          mkdir -p "$out/lib";
          mv ./libmysqlclient.so "$out/lib/";

          runHook postInstall
        '';

        meta = {
          description = "Make your team work together. On the same binary, synchronized across all devices.";
          homepage = "https://hex-rays.com/teams";
          license = lib.licenses.unfree;
          platforms = lib.singleton "x86_64-linux";
          mainProgram = "vault_server";
        };
      });
    in
    {
      packages = lib.filterAttrs (_: lib.meta.availableOn pkgs.stdenv.hostPlatform) {
        inherit hexvault;
      };
    };
}
