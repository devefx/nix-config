# modules/nixos/server

**English** | [简体中文](./README.zh-CN.md)

Server / VM / appliance modules. **Not** auto-imported — hosts pick specific files into their own
`nixos-modules` list.

## Contents

| File             | For                                                                                                                                                                                                                                                                                                                             |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `llama-cpp.nix`  | llama.cpp 0.7.0 server (Vulkan backend) over the `gguf-model-presets` tree. Same shape as `gufo.nix`, but the unit has no `wantedBy` — it is registered and started by hand, because it competes with gufo for ~85-90 GiB of unified memory. It listens on llama.cpp's own default 9931, so the two do not fight over a socket. |
| `qemu-guest.nix` | NixOS running as a QEMU/KVM guest — Proxmox VE, KubeVirt, plain libvirt. Adds qemu-guest-agent, virtio bootloader, serial console, `boot.growPartition`, disables cloud-init.                                                                                                                                                   |

## How a host uses it

Add the specific file to the host's nixos-modules list:

```nix
# outputs/x86_64-linux/src/<vm-host>.nix
nixos-modules = map mylib.relativeToRoot [
  "modules/nixos"
  "modules/nixos/server/qemu-guest.nix"    # ← explicit, per-file
  "hosts/${name}"
];
```

No group-level import, no options toggle — this is "infrastructure, pick what you need".

The one exception is `llama-cpp.nix`: the file is still imported explicitly (that is what registers the
`modules.llamaCppServer.*` options), but the server itself is switched on per host with
`modules.llamaCppServer.enable = true;` so a host can import it once and toggle it without touching
the module list. Unlike gufo it is never started at boot — see the note in the file.

## Why not the options pattern?

Server modules tend to be **platform-specific infrastructure** rather than features. A host is
either a QEMU guest or it isn't — you don't conditionally toggle virtio drivers. Explicit per-file
imports make that choice visible in the host's module list.

## Adding a server module

Drop `<name>.nix` here with config that makes sense to import into a specific subset of hosts (e.g.
`k3s-server.nix`, `k3s-agent.nix`, `kubevirt-guest.nix`). Don't use `scanPaths` — if a `default.nix`
in this dir auto-scanned, it would defeat the per-file opt-in.
