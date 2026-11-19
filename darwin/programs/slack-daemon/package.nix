# slack-daemond: the Python program launchd runs. The tests run in checkPhase.
{ lib, python3Packages }:

python3Packages.buildPythonApplication {
  pname = "slack-daemon";
  version = "0.1.0";
  pyproject = true;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [ ./pyproject.toml ./src ./tests ];
  };

  build-system = [ python3Packages.setuptools ];
  dependencies = with python3Packages; [
    anthropic
    pydantic
    websocket-client
  ];
  nativeCheckInputs = [ python3Packages.pytestCheckHook ];
  pythonImportsCheck = [ "slack_daemon.cli" ];

  meta.platforms = lib.platforms.darwin;
}
