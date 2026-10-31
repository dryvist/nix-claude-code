{ pkgs, src }:
let
  # renovate: datasource=pypi depName=textual
  textualVersion = "8.2.8";
  textual = pkgs.python3Packages.textual.overridePythonAttrs (_: {
    version = textualVersion;
    src = pkgs.fetchPypi {
      pname = "textual";
      version = textualVersion;
      hash = "sha256-PxBqn7xz453SZslxJDIIfeeKbWRAhMfCQdaiXDFpEVs=";
    };
  });
in
pkgs.python3Packages.buildPythonApplication {
  pname = "claude-swap";
  # renovate: datasource=github-releases depName=realiti4/claude-swap
  version = "0.28.0";
  inherit src;

  pyproject = true;
  build-system = [ pkgs.python3Packages.hatchling ];
  dependencies = [
    textual
    pkgs.python3Packages.truststore
  ];

  pythonImportsCheck = [ "claude_swap" ];
}
