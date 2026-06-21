{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  buildPythonPackage,
  python,
  importlib-resources,
  zlib,
}:

let
  version = "13.1.201.22";
  pythonTag = "cp${builtins.replaceStrings [ "." ] [ "" ] python.pythonVersion}";

  wheels = {
    "cp39-x86_64-linux" = {
      platform = "manylinux_2_31_x86_64";
      hash = "sha256-v1FXjshNumUZ11yoGhVKBwkQ5jjaDsOE9L9tU1+bUhg=";
    };
    "cp310-x86_64-linux" = {
      platform = "manylinux_2_31_x86_64";
      hash = "sha256-kFaP8I368OvTvxx599IdsG2C6tpBKm6RS5lb6tfHhmY=";
    };
    "cp311-x86_64-linux" = {
      platform = "manylinux_2_31_x86_64";
      hash = "sha256-2m2PKUW9BXBXxkvJPqPAZMyEi3X1XW1lESDuXRFeB2E=";
    };
    "cp312-x86_64-linux" = {
      platform = "manylinux_2_31_x86_64";
      hash = "sha256-wkqkIVxk231n/GxCwNdzHKvPMAWWv5yCaudPQm/jt3E=";
    };
    "cp313-x86_64-linux" = {
      platform = "manylinux_2_31_x86_64";
      hash = "sha256-g0uXYbt/SdqLiHhHx2R0laLPbEX2niEkrg4/AkSTvBU=";
    };
  };

  wheel =
    wheels."${pythonTag}-${stdenv.hostPlatform.system}"
      or (throw "stpyv8: unsupported Python/platform combination: ${pythonTag}-${stdenv.hostPlatform.system}");
in
buildPythonPackage {
  pname = "stpyv8";
  inherit version;
  format = "wheel";

  src = fetchurl {
    url = "https://github.com/cloudflare/stpyv8/releases/download/v${version}/stpyv8-${version}-${pythonTag}-${pythonTag}-${wheel.platform}.whl";
    inherit (wheel) hash;
  };

  dontBuild = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];

  dependencies = lib.optionals (python.pythonOlder "3.10") [ importlib-resources ];

  pythonImportsCheck = [ "STPyV8" ];

  meta = {
    description = "Python wrapper for the Google V8 JavaScript engine";
    homepage = "https://github.com/cloudflare/stpyv8";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
