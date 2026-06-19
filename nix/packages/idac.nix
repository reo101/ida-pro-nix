{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  gitMinimal,
  pytest,
  python,
  uv-build,
}:

buildPythonPackage rec {
  pname = "idac";
  version = "0.17.0";
  pyproject = true;
  outputs = [
    "out"
    "plugin"
    "skill"
  ];

  src = fetchFromGitHub {
    owner = "trailofbits";
    repo = "idac";
    tag = "v${version}";
    hash = "sha256-X/+m+G9yFgqmdUK6F4A+3HdwDwYJ9OVGAaQOyFs//D0=";
  };

  build-system = [ uv-build ];

  makeWrapperArgs = [
    "--prefix"
    "PYTHONPATH"
    ":"
    "$out/${python.sitePackages}"
  ];

  postInstall = ''
    mkdir -p "$plugin" "$skill"

    ln -s "$out/${python.sitePackages}/idac/ida_plugin/idac_bridge" "$plugin/idac_bridge"
    ln -s "$out/${python.sitePackages}/idac/ida_plugin/idac_bridge_plugin.py" "$plugin/idac_bridge_plugin.py"
    ln -s "$out/${python.sitePackages}/idac" "$plugin/idac"

    cp -a src/idac/skills/idac/. "$skill/"
  '';

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'uv_build>=0.9.18,<0.10.0' 'uv_build'

    substituteInPlace src/idac/transport/idalib_common.py \
      --replace-fail 'import os
import sys' 'import os
import shutil
import sys' \
      --replace-fail 'elif sys.platform.startswith("linux"):
        for pattern in ("ida*", "IDA*"):' 'elif sys.platform.startswith("linux"):
        if ida := shutil.which("ida"):
            candidates.append(Path(ida).resolve().parent)
        for pattern in ("ida*", "IDA*"):'

    substituteInPlace src/idac/doctor.py \
      --replace-fail 'import json
import subprocess' 'import json
import os
import subprocess' \
      --replace-fail '        probe = subprocess.run(
            [str(executable), "-A", f"-L{log}", f"-S{script}", "-t"],' '        env = os.environ.copy()
        env.pop("PYTHONPATH", None)
        env["PATH"] = os.pathsep.join(
            part for part in env.get("PATH", "").split(os.pathsep) if "python" not in part and "idac" not in part
        )
        env["IDADIR"] = str(executable.parent)
        probe = subprocess.run(
            [str(executable), "-A", f"-L{log}", f"-S{script}", "-t"],' \
      --replace-fail '            timeout=IDA_LICENSE_PROBE_TIMEOUT_SECONDS,
        )' '            timeout=IDA_LICENSE_PROBE_TIMEOUT_SECONDS,
            env=env,
        )'
  '';

  nativeCheckInputs = [
    gitMinimal
    pytest
  ];

  checkPhase = ''
    runHook preCheck

    substituteInPlace tests/test_cli.py \
      --replace-fail 'def test_function_metadata_smoke(' '@pytest.mark.skip(reason="needs idalib")
def test_function_metadata_smoke(' \
      --replace-fail 'def test_batch_allows_preview_and_writes_jsonl(' '@pytest.mark.skip(reason="needs idalib")
def test_batch_allows_preview_and_writes_jsonl('

    pytest -o addopts= tests \
      --ignore=tests/test_gui_transport_live.py \
      --ignore=tests/test_output_limits.py \
      --ignore=tests/test_preview.py \
      --ignore-glob='tests/test_idalib*.py'

    runHook postCheck
  '';

  pythonImportsCheck = [ "idac" ];

  meta = {
    description = "Agent-friendly CLI for IDA with GUI and idalib backends";
    homepage = "https://github.com/trailofbits/idac";
    license = lib.licenses.unfree;
    mainProgram = "idac";
  };
}
