{ pkgs, llm-agents, ... }:
# Cross-platform dev-workflow tools — AI coding agents (main content),
# plus HTTP / network analysis utilities.
#
# The AI agents come from the `llm-agents.nix` flake input, which packages
# each vendor's official CLI. Install one, several, or comment out the
# ones you don't use — they're independent.
{
  home.packages =
    with pkgs;
    [
      # -------- Network / HTTP debugging --------
      mitmproxy # intercepting HTTP/HTTPS proxy, script-able
      wireshark # network packet analyzer
    ]
    # -------- AI Agent CLIs --------
    ++ (
      with llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      [
        claude-code # Anthropic Claude Code — what you're using right now
        codex # OpenAI Codex CLI (GPT-based coding agent)
        gemini-cli # Google Gemini CLI
        cursor-cli # Cursor's CLI
        opencode # opencode — open-source coding agent

        # -------- Utilities --------
        rtk # Rust Token Killer — proxy that reduces LLM token usage 60-90%
      ]
    );
}
