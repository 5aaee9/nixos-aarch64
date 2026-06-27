# Repart Image Module Refactor Spec

## Goal

Make this repository usable as a reusable NixOS module source for downstream image builds while reducing duplicate image-building code in `packages/default.nix`.

Downstream users should be able to import a board module plus an image-helper module from this repo, define their own `image.repart.partitions`, and build their own image through a dedicated `config.system.build` attribute. This repo's own repart image packages should use the same reusable module path.

## Current State

- `packages/default.nix` contains duplicated `buildRepartConfig` calls, btrfs root/ESP repart definitions, U-Boot raw writes, `sgdisk --verify`, and Hydra product metadata for FastRhino R68S and Radxa E20C.
- Board kernel modules such as `modules/radxa-e20c-kernel` are already importable NixOS modules and configure boot/kernel details, not image layout.
- `modules/sdimage` wraps upstream `sd-image.nix` for older image packages.
- No public documentation explains how to import this repo to build a custom repart image.

## Design

### Module Architecture

Add reusable image modules under `modules/` and export them from `modules/default.nix`:

- `nixosModules.repart-image` from `modules/repart-image/default.nix`
  - Imports upstream NixOS `image/repart.nix` and `system/boot/systemd/repart.nix`.
  - Relies on the upstream repart module behavior in this repo's nixpkgs: importing `image/repart.nix` defines `config.system.build.image` from `config.image.repart` without an `image.repart.enable` option.
  - Uses the pinned nixpkgs repart compression option path `image.repart.compression.enable`, as defined by this repo's current `nixos/modules/image/repart.nix`.
  - Asserts the required upstream contract by checking that `config.system.build.image` exists after imports.
  - Provides a repo-owned option namespace `nixos-aarch64.repartImage`.
  - Provides `config.system.build.repartImage`, a separate dependent derivation that copies and post-processes the already-built upstream `config.system.build.image`.
  - Defaults only to generic build behavior and does not define root, ESP, or product-specific partition layouts by itself.
  - Supports raw uncompressed repart images for post-processing. It sets `image.repart.compression.enable = lib.mkDefault false` and adds a NixOS `assertions` entry requiring `config.image.extension == "raw"` before wrapping.
  - Copies `${config.system.build.image}/${config.image.baseName}.${config.image.extension}` to `$out/sd-image/${config.image.baseName}.raw`, runs configured post-processing commands with `img` set to that absolute output path, verifies GPT with `sgdisk --verify` by default, and emits Hydra `file sd-image` metadata.
  - Adds `pkgs.gptfdisk` to `nativeBuildInputs` when GPT verification is enabled.

- `nixosModules.repart-btrfs-esp` from `modules/repart-btrfs-esp/default.nix`
  - Defines this repo's default product layout for simple bootable images:
    - `/` mounted from `/dev/disk/by-label/NIXOS_ROOT` as btrfs.
    - `/boot/efi` mounted from `/dev/disk/by-label/FIRMWARE` as vfat with `nofail`, and left auto-mountable so systemd-boot activation can update it.
    - `boot.supportedFilesystems` and `boot.initrd.supportedFilesystems` force `vfat` and `btrfs`, preserving the current repo image behavior.
    - `boot.initrd.systemd.enable = true`.
    - initrd repart enabled with matching runtime root partition definition.
    - `boot.loader.systemd-boot` enabled and `boot.loader.generic-extlinux-compatible` disabled for systemd-boot image layouts.
    - `boot.loader.efi.canTouchEfiVariables = false` and `boot.loader.efi.efiSysMountPoint = "/boot/efi"`.
    - The image seeds the ESP using the same paths managed by NixOS `boot.loader.systemd-boot`: systemd-boot EFI binaries, `/loader/loader.conf`, `/loader/entries/nixos.conf`, and kernel/initrd/device-tree files under `/EFI/nixos`.
    - Adds NixOS `assertions` entries requiring `boot.loader.systemd-boot.enable == true` and `boot.loader.generic-extlinux-compatible.enable == false`; these are the concrete bootability preconditions for the systemd-boot layout in this repo's pinned nixpkgs.
    - Evaluation checks must also force the ESP content paths that systemd-boot activation updates.
    - `image.repart.partitions."10-esp"` containing initial systemd-boot-managed boot files.
    - `image.repart.partitions."20-root"` containing `config.system.build.toplevel`.
    - `image.repart.imageSize = "auto"` and btrfs shrink mkfs option.
  - This module is intentionally separate from board modules so downstream users can replace it with their own partition scheme.

- `nixosModules.rockchip-uboot-repart` from `modules/rockchip-uboot-repart/default.nix`
  - Defines the reserved Rockchip U-Boot GPT partition that must exist in repart images when a board needs raw Rockchip loader writes.
  - Provides a default `image.repart.partitions."00-uboot"` entry with the current custom GUID, 15M size, and no padding.
  - Provides `nixos-aarch64.rockchipUbootRepart.label`, defaulting to the existing Radxa-compatible label `E20C_UBOOT`; this value is assigned to the partition definition's `Label`.
  - Does not define root or ESP partitions.

### Public Options

`nixos-aarch64.repartImage` should include:

- `name`: image basename. Defaults to `"nixos-repart"`.
  - `repart-image` assigns `image.repart.name = lib.mkDefault config.nixos-aarch64.repartImage.name`, so downstream users can set either `nixos-aarch64.repartImage.name` or override `image.repart.name` directly.
  - Canonical output naming follows upstream `config.image.baseName`: upstream derives it from `config.image.repart.name` plus optional `image.repart.version`, and downstream users may override `image.baseName` directly if needed.
  - The wrapper output path is `$out/sd-image/${config.image.baseName}.raw`, keeping upstream repart and `system.build.repartImage` names aligned after all NixOS option overrides.
- `postBuildCommands`: shell snippet run after copying the upstream raw image. The snippet receives `img` pointing at the copied raw image.
- `verify`: boolean, default true, controls `sgdisk --verify`.
- `hydraBuildProduct`: boolean, default true, controls writing `$out/nix-support/hydra-build-products`.

The wrapped derivation must expose `config.system.build.repartImage`. It should not replace upstream `config.system.build.image`; upstream repart behavior remains available.
Board-specific raw U-Boot writes are supplied by package/downstream configurations through `nixos-aarch64.repartImage.postBuildCommands`, not by board kernel modules.
Layout modules that define `image.repart.partitions` are documented as intended to be imported with `repart-image`; they do not import upstream repart themselves to avoid hidden image-builder behavior in layout-only modules. `image.repart.partitions` defines the build-time image layout, while `systemd.repart.partitions` defines the runtime initrd repart/grow behavior.
The option namespace is intentionally repo-owned (`nixos-aarch64.*`) and remains stable regardless of a downstream flake input alias.

### Package Refactor

Refactor `packages/default.nix` to:

- Keep package names stable, including `repart-fastrhino-r68s` and `repart-radxa-e20c`.
- Replace duplicated repart image construction with shared helpers.
- Preserve the current common modules in repart package evaluations unless there is an explicit reason to remove one:
  - `firstBoot`,
  - `apply-overlay`,
  - `cross`.
- Build the repo's default repart images by importing:
  - the board kernel module,
  - `nixosModules.repart-image`,
  - `nixosModules.repart-btrfs-esp`,
  - `nixosModules.rockchip-uboot-repart` for both Radxa E20C and FastRhino R68S, because both default repart images write Rockchip loader artifacts at raw offsets and should reserve that disk space in the GPT layout,
  - board-specific U-Boot post-build commands.
- Preserve current output shape: `$out/sd-image/<image-name>.raw` and Hydra build product metadata.
- Preserve current U-Boot offsets:
  - idbloader at `seek=64`,
  - u-boot.itb at `seek=16384`.
- Remove ESP/root repart partition definitions from `packages/default.nix`; those definitions should live in `modules/repart-btrfs-esp`.
- Keep board modules free of `sdImage` options so they remain importable in plain NixOS and repart-image evaluations.
- Add `checks` that evaluate module semantics without building full images:
  - plain board-module import checks for Radxa E20C and FastRhino R68S,
  - refactored repart layout checks for Radxa E20C and FastRhino R68S,
  - wrapper option checks for `postBuildCommands`, `verify`, and `hydraBuildProduct`.

### Documentation

Add user-facing documentation under `docs/` explaining:

- Which modules to import for a custom image.
- That board modules configure boot/kernel behavior and avoid owning arbitrary image layouts.
- That `repart-image` provides `config.system.build.repartImage`.
- That downstream users should define their own `image.repart.partitions` for root/ESP/data layouts.
- That Rockchip boards needing raw loader space can import `rockchip-uboot-repart` to get only the reserved U-Boot partition.
- That `/boot/efi` is mounted with `nofail` but not `noauto`, because NixOS systemd-boot activation must be able to update the ESP after normal system switches.
- The distinction between build-time `image.repart.partitions` and runtime `systemd.repart.partitions`.
- A minimal flake/NixOS example using Radxa E20C, `repart-image`, `rockchip-uboot-repart`, and custom repart partitions.

## Acceptance Criteria

- `nix flake check --no-build` succeeds.
- `nix eval .#nixosModules.repart-image` succeeds.
- `nix eval .#nixosModules.repart-btrfs-esp` succeeds.
- `nix eval .#nixosModules.rockchip-uboot-repart` succeeds.
- The Radxa E20C and FastRhino R68S board modules evaluate in a plain NixOS configuration without importing `sdimage` or repart image modules.
- `nix eval .#packages.x86_64-linux.repart-radxa-e20c.drvPath` succeeds.
- `nix eval .#packages.x86_64-linux.repart-fastrhino-r68s.drvPath` succeeds.
- `checks.x86_64-linux.radxa-e20c-repart-layout` and `checks.x86_64-linux.fastrhino-r68s-repart-layout` evaluate successfully and assert the expected image base names and `$out/sd-image/${config.image.baseName}.raw` wrapper structure.
- `checks.x86_64-linux.repart-image-options` evaluates successfully and covers public wrapper options:
  - `postBuildCommands` is included in the wrapper builder and runs with `img=$out/sd-image/${config.image.baseName}.raw`.
  - `verify = true` includes `sgdisk --verify` and `pkgs.gptfdisk`; `verify = false` omits them.
  - `hydraBuildProduct = true` writes `$out/nix-support/hydra-build-products`; `false` omits it.
- Evaluation checks for the refactored Radxa E20C and FastRhino R68S image configurations assert:
  - `/` uses `/dev/disk/by-label/NIXOS_ROOT` as btrfs.
  - `/boot/efi` uses `/dev/disk/by-label/FIRMWARE` as vfat and does not use `noauto`.
  - `image.repart.partitions` contains `00-uboot`, `10-esp`, and `20-root`.
  - `systemd.repart.partitions."20-root"` matches the btrfs root layout.
  - systemd-boot is enabled and generic extlinux is disabled.
  - no A/B `/nix/store` or separate `/var` repart partitions are introduced.
- A build-based smoke check for at least one wrapped repart image succeeds far enough to realize the wrapper derivation command graph, preferably `nix build .#packages.x86_64-linux.repart-radxa-e20c --dry-run` when a full image build is too expensive.
- Documentation exists under `docs/` and describes downstream custom repart image usage.
- `packages/default.nix` no longer contains inline `image.repart.partitions."10-esp"` or `"20-root"` ESP/root layout definitions.
- Existing sdimage packages remain functionally unchanged.

## Out of Scope

- Building all full images during verification.
- Changing non-repart sdimage behavior.
- Adding A/B store partitions, a separate `/var`, or product-specific downstream layouts.
- Replacing board kernel modules with image modules.
