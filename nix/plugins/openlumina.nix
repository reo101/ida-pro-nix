{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ida-sdk,
  writeText,
  ...
}:

rec {
  pname = "openlumina";
  version = "9.3.0";

  drv = stdenv.mkDerivation {
    inherit pname;
    inherit version;

    src = fetchFromGitHub {
      owner = "tomrus88";
      repo = "OpenLumina";
      rev = "v${version}";
      hash = "sha256-lXhoJYapcHr86D9m0OU8iOhrhhcQNTB2j5/ZiJiT7Bg=";
    };

    nativeBuildInputs = [ cmake ];

    cmakeFlags = [
      (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
      (lib.cmakeFeature "IdaSdk_DIR" "${ida-sdk}/src")
      (lib.cmakeFeature "DIDA_90_STABLE" "1")
    ];

    patches = [
      (writeText "idausrdir.patch" ''
        diff --git a/OpenLumina/OpenLumina.cpp b/OpenLumina/OpenLumina.cpp
        index 31211baa..89990e23 100644
        --- a/OpenLumina/OpenLumina.cpp
        +++ b/OpenLumina/OpenLumina.cpp
        @@ -210,7 +210,7 @@ struct file_enumerator_impl : file_enumerator_t
         
         bool plugin_ctx_t::init_hook()
         {
        -    const char* ida_dir = idadir(nullptr);
        +    const char* ida_dir = get_user_idadir();
         
             char answer[QMAXPATH];

      '')
    ];

    installPhase = ''
      mkdir -p $out;
      cp OpenLumina${stdenv.hostPlatform.extensions.sharedLibrary} $out/;
      cp $src/ida-plugin.json $out/;
    '';
  };
}
