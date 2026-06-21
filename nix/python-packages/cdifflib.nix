{
  lib,
  buildPythonPackage,
  fetchPypi,
  python,
}:

buildPythonPackage rec {
  pname = "cdifflib";
  version = "1.2.9";
  format = "setuptools";

  disabled = python.pythonOlder "3.4";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-YobaCPcrfdtbQBRdy48hStkTqG1ysfYsyNbPepIClZA=";
  };

  pythonImportsCheck = [
    "_cdifflib"
    "cdifflib"
  ];

  meta = {
    description = "C implementation of parts of difflib";
    homepage = "https://github.com/mduggan/cdifflib";
    license = lib.licenses.bsd3;
  };
}
