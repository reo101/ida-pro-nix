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
in
rec {
  pname = "hrtng";
  version = "3.9.0-dev";

  drv = stdenv.mkDerivation rec {
    inherit pname version;

    src = fetchFromGitHub {
      owner = "reo101";
      repo = "hrtng";
      rev = "fa74d36375e8aec3f9ef2ba3b745ea7212bb35b7";
      fetchSubmodules = true;
      hash = "sha256-wBamN8As8RTfYidHplqV4cOH80xHSW+najaTO9n3sIY=";
    };

    sourceRoot = "${src.name}/src";

    nativeBuildInputs = [
      binutils
      cmake
    ];

    postPatch = ''
      ln -s ${cryptoppSrc} cryptopp
      substituteInPlace helpers.cpp \
        --replace-fail 'add_extra_cmt(ea, true, cmt.c_str());' 'add_extra_cmt(ea, true, "%s", cmt.c_str());'
    '';

    preConfigure = ''
      cmakeFlagsArray+=("-DCRYPTOPP_SOURCES:PATH=$PWD/cryptopp")
    '';

    cmakeFlags = [
      # (lib.cmakeOptionType "PATH" "CRYPTOPP_SOURCES" "${cryptoppSrc}")
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
