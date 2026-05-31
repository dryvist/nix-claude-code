# Claude Code Plugin Marketplaces (canonical catalog)
#
# CRITICAL: Marketplace Keys MUST Match Manifest Names
# ============================================================================
# Each key MUST match the `name` field in the repo's .claude-plugin/marketplace.json
#
# Example:
#   GitHub repo: anthropics/skills
#   manifest name: "anthropic-agent-skills" (from marketplace.json)
#   Nix key: "anthropic-agent-skills" ← MUST MATCH manifest name
#   Plugin reference: "example-skills@anthropic-agent-skills"
#
# DO NOT use arbitrary keys like "skills" or GitHub paths like "anthropics/skills"
#
# Required fields per marketplace:
#   - source.type: "github" (lowercase, always)
#   - source.url: "owner/repo" format (GitHub path)
#
# IMPORTANT: Marketplace URL Format and Plugin References
# ========================================================================
# INPUT FORMAT (what we define here):
#   type: "github"     (for GitHub repositories)
#   url: "owner/repo"  (GitHub org/repo format, NOT full URL)
#
# OUTPUT FORMAT (after transformation via lib/claude-registry.nix):
#   source: "github"
#   repo: <value from source.url>  # The actual GitHub path for fetching
#
# MARKETPLACE DISPLAY NAMES:
# - Standard: Key = "owner/repo", display name = repo (extracted by getMarketplaceName)
# - Special: Some marketplaces use org-name as display (e.g., WakaTime uses "wakatime")
# - Plugin references: "plugin-name@display-name" (e.g., "claude-code-wakatime@wakatime")
#
# SPECIAL CASES (key differs from owner/repo pattern):
# - WakaTime: Key = "wakatime", URL = "wakatime/claude-code-wakatime"
#   Official: claude plugin i claude-code-wakatime@wakatime
# ========================================================================

{
  lib,
  ...
}:

let
  # Validate marketplace entry has correct nested structure
  # Claude Code schema: { "id": { source: { type: "git", url: "..." } } }
  validateMarketplace =
    name: value:
    assert lib.assertMsg (builtins.isAttrs value)
      "Marketplace '${name}' must be an attrset, got ${builtins.typeOf value}";
    assert lib.assertMsg (
      value ? source && builtins.isAttrs value.source
    ) "Marketplace '${name}' must have a 'source' attrset";
    assert lib.assertMsg (
      value.source ? type && builtins.isString value.source.type
    ) "Marketplace '${name}.source' must have a 'type' string (git, github, local)";
    assert lib.assertMsg (
      value.source ? url && builtins.isString value.source.url
    ) "Marketplace '${name}.source' must have a 'url' string";
    true;

  # ============================================================================
  # Marketplace Definitions
  # ============================================================================
  marketplaces = {
    # --- Personal Plugins ---
    # JacobPEvans's curated plugins. Consumers register a synthetic
    # derivation (see jacobpevansMarketplace in marketplace-overrides.nix)
    # because the upstream marketplace.json doesn't list every plugin dir.
    "jacobpevans-cc-plugins" = {
      source = {
        type = "github";
        url = "JacobPEvans/claude-code-plugins";
      };
    };

    # --- Official Anthropic ---
    "claude-plugins-official" = {
      source = {
        type = "github";
        url = "anthropics/claude-plugins-official";
      };
    };
    "anthropic-agent-skills" = {
      source = {
        type = "github";
        url = "anthropics/skills";
      };
    };

    # --- AI/ML ---
    "huggingface-skills" = {
      source = {
        type = "github";
        url = "huggingface/skills";
      };
    };

    # --- Community ---
    "cc-marketplace" = {
      source = {
        type = "github";
        url = "ananddtyagi/cc-marketplace";
      };
    };
    "bills-claude-skills" = {
      source = {
        type = "github";
        url = "BillChirico/bills-claude-skills";
      };
    };
    "superpowers-marketplace" = {
      source = {
        type = "github";
        url = "obra/superpowers-marketplace";
      };
    };

    # --- Infrastructure & DevOps ---
    "lunar-claude" = {
      source = {
        type = "github";
        url = "basher83/lunar-claude";
      };
    };
    "claude-code-plugins-plus" = {
      source = {
        type = "github";
        url = "jeremylongshore/claude-code-plugins-plus";
      };
    };
    "claude-code-workflows" = {
      source = {
        type = "github";
        url = "wshobson/agents";
      };
    };

    # --- Time Tracking ---
    "wakatime" = {
      source = {
        type = "github";
        url = "wakatime/claude-code-wakatime";
      };
    };

    # --- Claude Skills Marketplace ---
    "claude-skills" = {
      source = {
        type = "github";
        url = "secondsky/claude-skills";
      };
    };

    # --- Additional Community Marketplaces ---
    # Multi-model AI integrations (OpenAI, Gemini) and notifications
    "cc-dev-tools" = {
      source = {
        type = "github";
        url = "Lucklyric/cc-dev-tools";
      };
    };

    # --- Obsidian Skills ---
    # Canonical Obsidian skills from kepano (markdown, bases, canvas, CLI, utilities)
    "obsidian-skills" = {
      source = {
        type = "github";
        url = "kepano/obsidian-skills";
      };
    };

    # Independent visual diagram skills (Excalidraw, Mermaid, Canvas Creator)
    "axton-obsidian-visual-skills" = {
      source = {
        type = "github";
        url = "axtonliu/axton-obsidian-visual-skills";
      };
    };

    # --- Visualization ---
    # Rich HTML pages for diagrams, diff reviews, slides, data tables (nicobailon)
    "visual-explainer-marketplace" = {
      source = {
        type = "github";
        url = "nicobailon/visual-explainer";
      };
    };

    # --- Official OpenAI ---
    # OpenAI Codex plugin: code review, adversarial review, task delegation
    "openai-codex" = {
      source = {
        type = "github";
        url = "openai/codex-plugin-cc";
      };
    };

    # --- Enterprise / Well-Known ---
    # Bitwarden AI plugins: session retrospective, config validation, code review
    "bitwarden-marketplace" = {
      source = {
        type = "github";
        url = "bitwarden/ai-plugins";
      };
    };

    # --- Synthetic Marketplaces (repos with skills but no marketplace structure) ---
    # flakeInput for these is overridden by callers with a derivation from
    # marketplace-overrides.nix that wraps the raw skills into a proper
    # .claude-plugin directory layout.
    "browser-use-skills" = {
      source = {
        type = "github";
        url = "browser-use/browser-use";
      };
    };

    # VisiCore Cribl pack validator — lints .crbl pack files against pack standards.
    # Bare .claude/skills/ layout; wrapped into synthetic marketplace.
    "vct-cribl-pack-validator-skills" = {
      source = {
        type = "github";
        url = "VisiCore/vct-cribl-pack-validator";
      };
    };

    # Fabric patterns — Daniel Miessler's AI prompt patterns.
    # The upstream repo has no .claude-plugin/ structure, so we wrap a curated
    # subset into a synthetic marketplace (see fabricMarketplace in
    # marketplace-overrides.nix). Patterns become individual Claude Code skills.
    "fabric-patterns" = {
      source = {
        type = "github";
        url = "danielmiessler/fabric";
      };
    };

    # Karpathy skills — workflow patterns from Andrej Karpathy's
    # forrestchang/andrej-karpathy-skills repo.
    "karpathy-skills" = {
      source = {
        type = "github";
        url = "forrestchang/andrej-karpathy-skills";
      };
    };
  };

  # Validate all marketplaces at evaluation time
  validatedMarketplaces = lib.mapAttrs validateMarketplace marketplaces;
in
# Force evaluation of validations
assert lib.all (x: x) (lib.attrValues validatedMarketplaces);
{
  inherit marketplaces;
}
