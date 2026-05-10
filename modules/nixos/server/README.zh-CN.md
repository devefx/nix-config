# modules/nixos/server

[English](./README.md) | **简体中文**

服务器 / 虚拟机 / appliance 模块。**不是**自动导入 —— 主机按需
把具体文件塞进自己的 `nixos-modules` 列表。

## 目录内容

| 文件 | 适用场景 |
|------|---------|
| `qemu-guest.nix` | NixOS 作为 QEMU/KVM 客户机跑 —— Proxmox VE、KubeVirt、裸 libvirt。启用 qemu-guest-agent、virtio 启动、串口控制台、`boot.growPartition`,关掉 cloud-init。 |

## 主机如何使用

把具体文件加到主机的 nixos-modules 列表:

```nix
# outputs/x86_64-linux/src/<vm-host>.nix
nixos-modules = map mylib.relativeToRoot [
  "modules/nixos"
  "modules/nixos/server/qemu-guest.nix"    # ← 显式、按文件
  "hosts/${name}"
];
```

**没有**组级导入,**没有** options 开关 —— 这里是"基础设施,按需取用"。

## 为什么不用 options 开关模式

server 模块一般是**平台相关的基础设施**,不是"功能"。一台主机要么
是 QEMU guest 要么不是,不会动态开关 virtio 驱动。按文件显式 import
让这种选择在主机的模块列表里**一眼可见**。

## 新增 server 模块

扔一个 `<name>.nix` 到这里,内容针对特定子集主机(例如 `k3s-server.nix`、
`k3s-agent.nix`、`kubevirt-guest.nix`)。**不要** 在这个目录里加
`scanPaths` 形式的 `default.nix` —— 那会破坏"按文件 opt-in"的约定。
