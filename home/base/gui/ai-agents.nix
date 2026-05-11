{
  lib,
  pkgs,
  llm-agents,
  config,
  ...
}:
# AI coding agent CLIs — Claude Code, Codex, Gemini CLI, etc.
#
# Packages come from the `llm-agents.nix` flake input (pinned separately
# from nixpkgs so each vendor's supported version lands intact).
#
# Gated behind `modules.aiAgents.enable` — only hosts that actually
# develop with these agents pull the ~GB of Node / Go / Rust runtimes
# bundled with them. Enable in `home/hosts/<name>.nix`.
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.modules.aiAgents;
in
{
  options.modules.aiAgents = {
    enable = mkEnableOption "AI coding agent CLIs (Claude Code / Codex / Gemini / Cursor / opencode)";
  };

  config = mkIf cfg.enable {
    home.packages = with llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      claude-code # Anthropic Claude Code
      codex # OpenAI Codex CLI
      gemini-cli # Google Gemini CLI
      cursor-cli # Cursor's CLI
      opencode # opencode — open-source coding agent
      rtk # Rust Token Killer — proxy that reduces LLM token usage 60-90%
    ];
  };
}
