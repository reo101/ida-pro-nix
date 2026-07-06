{
  stdenv,
  fetchFromGitHub,
  ...
}:

rec {
  pname = "lighthouse";
  version = "0.9.3";

  drv = stdenv.mkDerivation rec {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "gaasedelen";
      repo = "lighthouse";
      rev = "v${version}";
      hash = "sha256-H2yVP4RlqBH65VlsAZBME3FTebEHbSfk/ZIj+qB3fLo=";
    };

    sourceRoot = "${src.name}/plugins";

    installPhase = ''
      cp -rT . $out;
    '';
  };

  installEntries = [
    "lighthouse"
    "lighthouse_plugin.py"
  ];
}
