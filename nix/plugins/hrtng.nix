{
  lib,
  stdenv,
  fetchFromGitHub,
  binutils,
  cmake,
  ida-pro-version,
  ida-sdk,
  ...
}:

let
  cryptoppSrc = fetchFromGitHub {
    owner = "weidai11";
    repo = "cryptopp";
    rev = "CRYPTOPP_8_9_0";
    hash = "sha256-HV+afSFkiXdy840JbHBTR8lLL0GMwsN3QdwaoQmicpQ=";
  };

  cryptoppCmakeSrc = fetchFromGitHub {
    owner = "abdes";
    repo = "cryptopp-cmake";
    rev = "d2b072ab65c036f3dca67f4204ad57d66728bf99";
    hash = "sha256-FHHGq8hpLIsT6xq3hXY2n0wVFO4ahVXkSuWsKKnfn/U=";
  };
in
rec {
  pname = "hrtng";
  version = "unstable-2026-07-07";

  drv = stdenv.mkDerivation rec {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "KasperskyLab";
      repo = "hrtng";
      rev = "6202adf445b28f34945d6fe9397064d092e68867";
      hash = "sha256-t1u4NxFO/crj/hUhJAWHgfOLROduV4Hz5Hwe18rs224=";
    };

    sourceRoot = "${src.name}/src";

    nativeBuildInputs = [
      binutils
      cmake
    ];

    postPatch = ''
      rm -rf cryptopp-cmake
      ln -s ${cryptoppCmakeSrc} cryptopp-cmake
      ln -s ${cryptoppSrc} cryptopp
      substituteInPlace helpers.cpp \
        --replace-fail 'add_extra_cmt(ea, true, cmt.c_str());' 'add_extra_cmt(ea, true, "%s", cmt.c_str());'
    '';

    preConfigure = ''
      cmakeFlagsArray+=("-DCRYPTOPP_SOURCES:PATH=$PWD/cryptopp")
    '';

    cmakeFlags = [
      (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
      (lib.cmakeFeature "IDASDK_VER" (lib.versions.pad 2 ida-pro-version))
      (lib.cmakeFeature "IDASDK_DIR" "${ida-sdk}/src")
      (lib.cmakeBool "CRYPTOPP_BUILD_TESTING" false)
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp hrtng${stdenv.hostPlatform.extensions.sharedLibrary} $out/
      cp $src/bin/plugins/apilist.txt $out/
      cp $src/bin/plugins/literal.txt $out/
      cp $src/ida-plugin.json $out/
      cp $src/logo.jpg $out/
      cp $src/README.md $out/

      runHook postInstall
    '';
  };
}
