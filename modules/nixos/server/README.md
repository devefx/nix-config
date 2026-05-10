# modules/nixos/server

**English** | [简体中文](./README.zh-CN.md)

Server / VM / appliance modules. **Not** auto-imported — hosts pick
specific files into their own `nixos-modules` list.

## Contents

| File | For |
|------|-----|
| `qemu-guest.nix` | NixOS running as a QEMU/KVM guest — Proxmox VE, KubeVirt, plain libvirt. Adds qemu-guest-agent, virtio bootloader, serial console, `boot.growPartition`, disables cloud-init. |

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

No group-level import, no options toggle — this is "infrastructure,
pick what you need".

## Why not the options pattern?

Server modules tend to be **platform-specific infrastructure** rather
than features. A host is either a QEMU guest or it isn't — you don't
conditionally toggle virtio drivers. Explicit per-file imports make
that choice visible in the host's module list.

## Adding a server module

Drop `<name>.nix` here with config that makes sense to import into a
specific subset of hosts (e.g. `k3s-server.nix`, `k3s-agent.nix`,
`kubevirt-guest.nix`). Don't use `scanPaths` — if a `default.nix` in
this dir auto-scanned, it would defeat the per-file opt-in.
