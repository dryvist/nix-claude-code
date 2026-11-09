# Never wait for a human

## Denials never wait for a human

A classifier denial is returned to Claude as a blocked tool call with the
reason `Blocked by classifier`; Claude tries an alternative and the session
keeps moving. Nothing pauses for a human.

The one rule class that breaks this is `permissions.ask`: ask rules are
evaluated _before_ the classifier and always force a prompt, even in auto
mode. `modules/settings.nix` therefore **asserts the ask list is empty** — a
non-empty one fails evaluation. Use `deny` for a hard boundary (it blocks
without waiting on anyone) or `autoMode.soft_deny` / `.hard_deny` to teach the
classifier.

## Human-wait dialogs are capped at five minutes

`askUserQuestionTimeout` defaults to `"5m"` (upstream's real default is
`"never"`), and `dialogExpiry` renders `"5m"` explicitly — Claude Code's own
default, pinned so it cannot move past the cap. `modules/settings.nix` asserts
that neither exceeds five minutes and rejects `"never"`, so no forwarded
dialog can hold a session open indefinitely.

Two upstream gaps the cap cannot close:

- The `askUserQuestionTimeout` timer never starts in background sessions or
  while Remote Control is connected, so an unanswered question there still
  waits for a human to return.
- Permission prompts are governed by neither timeout and never auto-resolve
  on idle; in this module's default configuration the auto-mode classifier
  answers them instead — see "Denials never wait for a human" above.
