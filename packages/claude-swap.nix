{ pkgs, src }:
let
  textual = pkgs.python3Packages.textual.overridePythonAttrs (_: {
    version = "8.2.8";
    src = pkgs.fetchPypi {
      pname = "textual";
      version = "8.2.8";
      hash = "sha256-PxBqn7xz453SZslxJDIIfeeKbWRAhMfCQdaiXDFpEVs=";
    };
  });
in
pkgs.python3Packages.buildPythonApplication {
  pname = "claude-swap";
  version = "0.25.0";
  inherit src;

  pyproject = true;
  build-system = [ pkgs.python3Packages.hatchling ];
  dependencies = [
    textual
    pkgs.python3Packages.truststore
  ];

  pythonImportsCheck = [ "claude_swap" ];
}
