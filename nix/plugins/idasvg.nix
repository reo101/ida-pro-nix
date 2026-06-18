{
  fetchFromGitHub,
  ...
}:

rec {
  pname = "idasvg";
  version = "0.1.0";

  drv = fetchFromGitHub {
    owner = "ChiChou";
    repo = "idasvg";
    rev = "v${version}";
    hash = "sha256-raB7wCMy4GAasSRsVKBpvgrKQrPgG4DYgd4BndByXDE=";
  };
}
