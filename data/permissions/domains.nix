_:
# Network domains permitted for `WebFetch` and equivalent tool calls.
#
# Vendored from
# ai-assistant-instructions/agentsmd/permissions/domains/webfetch.json
# (snapshot: 2026-06-09, source rev 3128b52). Domains are deliberately broad so subdomains
# resolve (subdomains of `github.com` are covered by listing `github.com`).
{
  webfetch = [
    "anthropic.com"
    "apple.com"
    "claude.com"
    "claudecodecommands.directory"
    "conventionalcommits.org"
    "docker.com"
    "geminicli.com"
    "github.blog"
    "github.com"
    "github.github.io"
    "github.io"
    "githubusercontent.com"
    "google.com"
    "google.dev"
    "hashicorp.com"
    "kubernetes.io"
    "mozilla.org"
    "nixos.org"
    "npmjs.com"
    "openai.com"
    "pypi.org"
    "python.org"
    "raw.githubusercontent.com"
    "raycast.com"
    "readthedocs.io"
    "rust-lang.org"
    "stackoverflow.com"
    "terraform.io"
    "typescriptlang.org"
  ];
}
