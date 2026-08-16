# Build-time validation for `programs.claude.settings`.
#
# PURE function — split out of `./settings.nix` to keep that file under the
# repo's 12KB per-file error limit (see `.file-size.yml`). Returns the list
# that `settings.nix` assigns to `assertions`; it is not a home-manager
# module of its own.
#
# `envAttrs` is the fully-merged environment block `settings.nix` computes
# (upstream defaults + autoCompact + caller `env` + apiKeyHelper), passed in
# rather than recomputed so both files cannot drift.
{
  lib,
  cfg,
  envAttrs,
}:

let
  # Validate POSIX environment variable names: ^[A-Z_][A-Z0-9_]*$
  isValidEnvVarName = name: builtins.match "^[A-Z_][A-Z0-9_]*$" name != null;
  invalidEnvVars = lib.filterAttrs (name: _: !isValidEnvVarName name) envAttrs;

  # Human-wait dialogs are capped at five minutes. Claude Code accepts
  # "60s"/"5m" style durations and the literal "never"; parse to seconds so
  # the assertions below can compare, and return `null` for anything that is
  # not a bounded duration ("never", or a typo) so it fails the check rather
  # than silently meaning "wait forever".
  humanWaitCapSeconds = 300;

  parseDurationSeconds =
    value:
    let
      m = builtins.match "([0-9]+)(s|m)" value;
      unitSeconds = if builtins.elemAt m 1 == "m" then 60 else 1;
    in
    if m == null then null else lib.toInt (builtins.elemAt m 0) * unitSeconds;

  isWithinHumanWaitCap =
    value:
    let
      seconds = parseDurationSeconds value;
    in
    seconds != null && seconds <= humanWaitCapSeconds;
in
[
  {
    assertion = invalidEnvVars == { };
    message = ''
      Invalid environment variable names in programs.claude.settings.env:
        ${lib.concatStringsSep ", " (builtins.attrNames invalidEnvVars)}

      Environment variable names must match POSIX convention: ^[A-Z_][A-Z0-9_]*$
      (uppercase letters, digits, and underscores only; must start with letter or underscore)
    '';
  }
  {
    assertion =
      cfg.settings.autoCompactThresholdPercent == null
      || (
        cfg.settings.autoCompactThresholdPercent >= 1 && cfg.settings.autoCompactThresholdPercent <= 100
      );
    message = "programs.claude.settings.autoCompactThresholdPercent must be between 1 and 100 (percent of context window).";
  }
  {
    assertion = cfg.settings.permissions.ask == [ ];
    message = ''
      programs.claude.settings.permissions.ask must be empty, but carries:
        ${lib.concatStringsSep ", " cfg.settings.permissions.ask}

      An `ask` rule is evaluated before the auto-mode classifier and always
      forces a permission prompt, even in auto mode. In a scheduled run, CI
      job, container, or overnight session no human arrives to answer it, so
      the session stalls until timeout and the goal is abandoned — a prompt
      nobody can answer is an outage, not a control.

      Use programs.claude.settings.permissions.deny for a boundary that must
      never be crossed (it blocks without waiting on anyone), or
      programs.claude.autoMode.soft_deny / .hard_deny to teach the classifier
      about it.
    '';
  }
  {
    assertion = isWithinHumanWaitCap cfg.settings.askUserQuestionTimeout;
    message = ''
      programs.claude.settings.askUserQuestionTimeout is
      "${cfg.settings.askUserQuestionTimeout}", which is not a bounded duration
      of at most ${toString humanWaitCapSeconds}s.

      Use a "<number>s" or "<number>m" value up to "5m". "never" is rejected:
      an unanswered dialog would hold the session open indefinitely.
    '';
  }
  {
    assertion = cfg.settings.dialogExpiry == null || isWithinHumanWaitCap cfg.settings.dialogExpiry;
    message = ''
      programs.claude.settings.dialogExpiry is
      "${toString cfg.settings.dialogExpiry}", which is not a bounded duration
      of at most ${toString humanWaitCapSeconds}s.

      Use a "<number>s" or "<number>m" value up to "5m", or leave it null to
      keep Claude Code's own 5m default.
    '';
  }
]
