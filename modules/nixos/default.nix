{ ... }:
{
  # Only auto-import base modules (mandatory for every host).
  # Other module groups like `desktop/` or `server/` are opt-in and
  # must be imported explicitly by the host that needs them.
  imports = [
    ./base
    ../base
  ];
}
