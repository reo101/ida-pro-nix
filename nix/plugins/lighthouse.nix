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

    # HACK: upstream is `gaasedelen`'s, this is an AI slop hotfix
    src = fetchFromGitHub {
      owner = "0xMirasio";
      repo = "lighthouse";
      rev = "f751943d59db031103f54472e8e10ed851dfb02c";
      hash = "sha256-jr4XJIHn9LD1VdMx4HllMoIZAsEeI5WNwUkLQyq1rLQ=";
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
