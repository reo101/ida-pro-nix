{
  fetchFromGitHub,
  ...
}:

rec {
  pname = "diaphora";
  version = "3.4.0";

  src = fetchFromGitHub {
    owner = "joxeankoret";
    repo = "diaphora";
    rev = version;
    hash = "sha256-BjqzGtsNzXgyleVWCPTNxjPGvg5s/fgjWriQiEQVeSI=";
  };

  neededPythonPackages = ps: with ps; [
    cdifflib
    scikit-learn
    numpy
    joblib
    pandas
  ];
}
