let
  # Nix string literals have no \u escape, so the ESC byte that fastfetch's
  # cursor-back trick needs is decoded from JSON once here.
  esc = builtins.fromJSON "\"\\u001b\"";
in
{
  # System info panel — the neofetch-style logo-plus-facts display, using
  # fastfetch's `examples/26.jsonc` layout: a bordered two-column table
  # ("Keys" / "Values") with a 16-colour swatch box underneath.
  #
  # Configured through home-manager's `programs.fastfetch`, which writes
  # $XDG_CONFIG_HOME/fastfetch/config.jsonc. The schema is documented at
  # https://github.com/fastfetch-cli/fastfetch/wiki/Json-Schema
  #
  # Not wired into shell startup on purpose: it prints ~30 lines, which is
  # noise in every new terminal. Run `fastfetch` when you want it.
  #
  # Differences from the upstream preset, both deliberate:
  #
  #   - The two `publicip` modules are gone. They query an external service on
  #     every run to report your public address and an approximate location,
  #     which means a network round-trip (slow on a bad link) and handing your
  #     IP to a third party for what is a cosmetic line. Add them back if you
  #     actually want that on screen.
  #
  #   - The border width is left as upstream. It is drawn with literal box
  #     characters plus a `\u001b[60D` cursor-back escape, so it only lines up
  #     while the value column fits in 60 cells. A long hostname or a CJK
  #     character in a path will shift the right border.
  programs.fastfetch = {
    enable = true;

    settings = {
      logo = {
        padding = {
          top = 2;
        };
      };

      display = {
        separator = "";
        constants = [
          # CONSTANT {$1} - VERTICAL BARS AT START AND 75th CHARACTERS FORWARD
          # AND BACKWARD. Every row re-emits this then jumps the cursor back,
          # which is what keeps the right border aligned without fastfetch
          # knowing the rendered width.
          #
          # The ESC bytes are built with fromJSON rather than written as
          # "\u001b": Nix string literals have no \u escape, so a literal
          # \u001b would reach the terminal as those six characters and the
          # border would render as visible "u001b[90m" noise.
          "${esc}[90m│                                                            │${esc}[60D${esc}[39m"
        ];
      };

      modules = [
        # --- Top border ---
        {
          type = "custom";
          key = "{#90}╭ Keys ───────╮";
          format = "{#90}╭ Values ────────────────────────────────────────────────────╮";
        }

        # --- Identity ---
        {
          type = "title";
          key = "{#90}│ {#92}User        {#90}│";
          format = "{$1}{user-name}  {#2}[{home-dir}]";
        }
        {
          type = "users";
          key = "{#90}│ {#92}Users       {#90}│";
          myselfOnly = false;
          format = "{$1}{1}@{host-name}{/host-name}localhost{/}{?client-ip}  {#2}[IP:{client-ip}]{?}  [Login time: {login-time}]";
        }
        {
          type = "datetime";
          key = "{#90}│ {#92}Datetime    {#90}│";
          format = "{$1}{year}-{month-pretty}-{day-in-month} {hour-pretty}:{minute-pretty}:{second-pretty}  {#2}[{weekday}] [W{week}] [UTC{offset-from-utc}]";
        }
        {
          type = "title";
          key = "{#90}│ {#93}Host        {#90}│";
          format = "{$1}{host-name}";
        }
        {
          type = "host";
          key = "{#90}│ {#93}Machine     {#90}│";
          format = "{$1}{name}  {#2}{version}";
        }

        # --- OS ---
        {
          type = "os";
          key = "{#90}│ {#93}OS          {#90}│";
          format = "{$1}{?pretty-name}{pretty-name}{?}{/pretty-name}{name}{/} {codename}  {#2}[v{version}] [{arch}]";
        }
        {
          type = "kernel";
          key = "{#90}│ {#93}Kernel      {#90}│";
          format = "{$1}{sysname}  {#2}[v{release}]";
        }
        {
          type = "uptime";
          key = "{#90}│ {#93}Uptime      {#90}│";
          format = "{$1}{?days}{days} Days + {?}{hours}:{minutes}:{seconds}";
        }

        # --- Hardware ---
        {
          type = "cpu";
          key = "{#90}│ {#91}CPU         {#90}│";
          showPeCoreCount = true;
          temp = true;
          format = "{$1}{name}  {#2}[C:{core-types}] [{freq-max}]";
        }
        {
          type = "gpu";
          key = "{#90}│ {#91}GPU         {#90}│";
          detectionMethod = "auto";
          driverSpecific = true;
          format = "{$1}{name}  {#2}[C:{core-count}]{?frequency} [{frequency}]{?} {#2}[{type}]";
        }
        {
          type = "memory";
          key = "{#90}│ {#91}Memory      {#90}│";
          format = "{$1}{used} / {total} ({percentage})";
        }
        {
          type = "disk";
          key = "{#90}│ {#91}Disk        {#90}│";
          format = "{$1}{size-used} / {size-total} ({size-percentage})";
        }
        {
          type = "poweradapter";
          key = "{#90}│ {#91}Power       {#90}│";
          format = "{$1}{name}";
        }

        # --- Session ---
        {
          type = "terminal";
          key = "{#90}│ {#95}Terminal    {#90}│";
          format = "{$1}{pretty-name}  {#2}[{version}] [PID:{pid}]";
        }
        {
          type = "terminalfont";
          key = "{#90}│ {#95}Font        {#90}│";
          format = "{$1}{name}  {#2}[{size}]";
        }
        {
          type = "shell";
          key = "{#90}│ {#95}Shell       {#90}│";
          format = "{$1}{pretty-name}  {#2}[v{version}] [PID:{pid}]";
        }

        # --- Network (local only) ---
        {
          type = "localip";
          key = "{#90}│ {#94}Local IPv4  {#90}│";
          showPrefixLen = true;
          showIpv4 = true;
          showIpv6 = false;
          showMtu = true;
          format = "{$1}{ifname}: {ipv4}  {#2}[MTU:{mtu}]";
        }
        {
          type = "localip";
          key = "{#90}│ {#94}Local IPv6  {#90}│";
          showPrefixLen = true;
          showIpv4 = false;
          showIpv6 = true;
          showMtu = true;
          format = "{$1}{ifname}: {ipv6}  {#2}[MTU:{mtu}]";
        }

        # --- Bottom border ---
        {
          type = "custom";
          key = "{#90}╰─────────────╯";
          format = "{#90}╰────────────────────────────────────────────────────────────╯";
        }

        "break"

        # --- Colour swatch: the terminal's own 16-colour palette, so a theme
        # change can be verified at a glance. Purely diagnostic. ---
        {
          type = "custom";
          key = " ";
          format = "{#90}╭ Colors ───────────────────────────────────────────────────────────────────╮";
        }
        {
          type = "custom";
          format = "{#90}│ {#40}    {#41}    {#42}    {#43}    {#44}    {#45}    {#46}    {#47}    {#}                                          {#90}│";
        }
        {
          type = "custom";
          format = "{#90}│ {#100}    {#101}    {#102}    {#103}    {#104}    {#105}    {#106}    {#107}    {#}                                          {#90}│";
        }
        {
          type = "custom";
          format = "{#90}╰───────────────────────────────────────────────────────────────────────────╯";
        }
      ];
    };
  };
}
