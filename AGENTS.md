# Repository Guidance

This repository provides reusable NixOS base modules for third-party systems.

- Device modules, including `modules/radxa-e20c-kernel`, must be importable as normal NixOS modules without image-builder-only options such as `sdImage`.
- Put reusable system behavior in modules using upstream NixOS options whenever possible. For E20C boot, enable `boot.loader.systemd-boot` in the module and keep `boot.loader.generic-extlinux-compatible` disabled.
- Keep image targets responsible for image layout, partition contents, and board-specific U-Boot offsets only.
- The default E20C repart image should use a by-label btrfs root filesystem mounted at `/`; do not add A/B `/nix/store` partitions or a separate `/var` partition unless a downstream product explicitly needs them.
- Prefer upstream NixOS mechanisms such as `boot.loader.systemd-boot`, `boot.uki`, `system.build.uki`, `systemd.repart.partitions`, `boot.initrd.systemd.repart`, and `image.repart.partitions` over hand-written `/loader`, `/loader/entries`, `/firmware`, or `repart.d` files.
- Avoid bespoke boot or partition hacks unless an upstream option cannot express the required behavior; document any unavoidable exception next to the code.
