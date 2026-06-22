# Repart Image Module Refactor Plan

Spec: `docs/specs/repart-image-modules.md`

## Tasks

- [ ] Add reusable modules:
  - `modules/repart-image/default.nix`
  - `modules/repart-btrfs-esp/default.nix`
  - `modules/rockchip-uboot-repart/default.nix`
- [ ] Export the new modules from `modules/default.nix`.
- [ ] Refactor `packages/default.nix`:
  - keep existing package names stable,
  - keep `firstBoot`, `apply-overlay`, and `cross` in repart evaluations,
  - use `config.system.build.repartImage`,
  - remove inline ESP/root repart layouts from package definitions,
  - reserve Rockchip U-Boot space for both Radxa E20C and FastRhino R68S,
  - move board-specific raw U-Boot writes into `nixos-aarch64.repartImage.postBuildCommands`.
- [ ] Add flake checks for:
  - plain board-module evaluation for Radxa E20C and FastRhino R68S,
  - Radxa E20C and FastRhino R68S repart layout semantics,
  - `repart-image` wrapper option semantics.
- [ ] Add documentation under `docs/` for downstream custom repart image usage.
- [ ] Format Nix files and run verification.

## Implementation Details

### `repart-image`

Implement `modules/repart-image/default.nix` as a NixOS module that imports:

- `${modulesPath}/image/repart.nix`
- `${modulesPath}/system/boot/systemd/repart.nix`

Define options under `nixos-aarch64.repartImage`:

- `name`: `str`, default `"nixos-repart"`.
- `postBuildCommands`: `lines`, default `""`.
- `verify`: `bool`, default `true`.
- `hydraBuildProduct`: `bool`, default `true`.

Set:

- `image.repart.name = lib.mkDefault cfg.name`
- `image.repart.compression.enable = lib.mkDefault false`

Add assertions:

- `config ? system && config.system.build ? image`
- `config.image.extension == "raw"`

Set `system.build.repartImage` to a dependent `pkgs.runCommand` that:

- copies `${config.system.build.image}/${config.image.baseName}.${config.image.extension}` to `$out/sd-image/${config.image.baseName}.raw`,
- sets `img` to that absolute copied path,
- runs `cfg.postBuildCommands`,
- runs `sgdisk --verify "$img"` only when `cfg.verify`,
- writes Hydra metadata only when `cfg.hydraBuildProduct`.

Use `nativeBuildInputs = lib.optional cfg.verify pkgs.gptfdisk` so `sgdisk` is available only when verification is enabled.

### `repart-btrfs-esp`

Implement `modules/repart-btrfs-esp/default.nix` as a layout-only NixOS module.
Do not import upstream repart modules here; only `repart-image` imports `image/repart.nix` and `system/boot/systemd/repart.nix`.

Set:

- btrfs root filesystem mounted by label at `/`,
- vfat firmware filesystem mounted by label at `/boot/firmware` with `nofail` and `noauto`,
- forced boot/initrd supported filesystems `[ "vfat" "btrfs" ]`,
- `boot.initrd.systemd.enable = true`,
- `boot.initrd.systemd.repart.enable = true`,
- `boot.loader.systemd-boot.enable = true`,
- `boot.loader.generic-extlinux-compatible.enable = lib.mkForce false`,
- `boot.loader.efi.canTouchEfiVariables = false`,
- `boot.loader.efi.efiSysMountPoint = "/boot/firmware"`,
- runtime `systemd.repart.partitions."20-root"` matching the root partition,
- build-time `image.repart.imageSize = "auto"`,
- build-time `image.repart.mkfsOptions.btrfs = [ "--shrink" ]`,
- build-time `image.repart.partitions."10-esp"` with systemd-boot and UKI contents,
- build-time `image.repart.partitions."20-root"` with `config.system.build.toplevel`.

Use these exact partition configs:

- `10-esp.repartConfig`: `Type = "esp"`, `Format = "vfat"`, `Label = "FIRMWARE"`, `SizeMinBytes = "128M"`, `SizeMaxBytes = "128M"`, `PaddingMinBytes = "0"`.
- `20-root.repartConfig`: `Type = "root-arm64"`, `Format = "btrfs"`, `Label = "NIXOS_ROOT"`, `SizeMinBytes = "5G"`, `PaddingMinBytes = "0"`, `GrowFileSystem = true`.

Add assertions:

- `config.boot.loader.systemd-boot.enable`
- `!config.boot.loader.generic-extlinux-compatible.enable`

### `rockchip-uboot-repart`

Implement `modules/rockchip-uboot-repart/default.nix` as a layout-only NixOS module.
Do not import upstream repart modules here.

Define `nixos-aarch64.rockchipUbootRepart.label` as a string defaulting to `E20C_UBOOT`.

Set `image.repart.partitions."00-uboot".repartConfig`:

- `Type = "8DA63339-0007-60C0-C436-083AC8230908"`
- `Label = config.nixos-aarch64.rockchipUbootRepart.label`
- `SizeMinBytes = "15M"`
- `SizeMaxBytes = "15M"`
- `PaddingMinBytes = "0"`

### Package Refactor

Replace the duplicated `buildRepartConfig` and wrapper commands with a shared helper that evaluates:

- upstream repart modules via `self.nixosModules.repart-image`,
- common modules `firstBoot`, `apply-overlay`, `cross`,
- a board kernel module,
- default layout modules,
- a small package-specific module setting image name and post-build U-Boot writes.

For the default repart images:

- `repart-radxa-e20c`: name `nixos-radxa-e20c-repart`, U-Boot package `radxa-e20c-uboot`.
- `repart-fastrhino-r68s`: name `nixos-fastrhino-r68s-repart`, U-Boot package `fastrhino-r68s-uboot`.

Both import `rockchip-uboot-repart`.
Both set `postBuildCommands` preserving the current Rockchip raw write offsets:

- `idbloader.img` at `seek=64`,
- `u-boot.itb` at `seek=16384`.

### Checks

Add checks in `packages/default.nix` under its existing `perSystem` output so package and check helpers stay together:

- `radxa-e20c-plain-module`
- `fastrhino-r68s-plain-module`
- `radxa-e20c-repart-layout`
- `fastrhino-r68s-repart-layout`
- `repart-image-options`

Use small `pkgs.runCommand` derivations with `passAsFile`/generated text from `builtins.toJSON` or direct Nix assertions to force evaluation. Avoid full image builds in checks.

### Documentation

Add `docs/repart-images.md` with:

- module responsibilities,
- custom downstream example,
- explanation of `system.build.repartImage`,
- partition ownership guidance,
- Rockchip reserved partition guidance,
- noauto/nofail firmware mount rationale,
- build-time versus runtime repart option distinction.
- a minimal Radxa E20C downstream flake/NixOS example importing `radxa-e20c-kernel`, `repart-image`, `rockchip-uboot-repart`, and custom `image.repart.partitions`.

## Verification

The flake checks must explicitly force these assertions:

- Plain board module checks:
  - Radxa E20C and FastRhino R68S evaluate without importing `sdimage`, `repart-image`, or layout image modules.
- Repart layout checks for Radxa E20C and FastRhino R68S:
  - `config.image.baseName` matches the expected default image name.
  - `config.system.build.repartImage` is a derivation whose builder text/arguments include `$out/sd-image/${config.image.baseName}.raw`.
  - `/` uses `/dev/disk/by-label/NIXOS_ROOT`, `fsType = "btrfs"`, and `neededForBoot = true`.
  - `/boot/firmware` uses `/dev/disk/by-label/FIRMWARE`, `fsType = "vfat"`, and includes `nofail` and `noauto`.
  - `image.repart.partitions` has exactly the expected default keys `00-uboot`, `10-esp`, and `20-root` for these images.
  - `image.repart.partitions."10-esp".contents` forces both systemd-boot and UKI source paths, including `config.system.boot.loader.ukiFile` and `config.system.build.uki`.
  - `image.repart.partitions."20-root".storePaths` includes `config.system.build.toplevel`.
  - `systemd.repart.partitions."20-root"` matches the btrfs root layout.
  - `boot.loader.systemd-boot.enable = true`.
  - `boot.loader.generic-extlinux-compatible.enable = false`.
  - no `image.repart.partitions` entry defines an A/B `/nix/store` or separate `/var` partition.
- Wrapper option check:
  - `postBuildCommands` appears in the wrapper builder and runs with `img=$out/sd-image/${config.image.baseName}.raw`.
  - `verify = true` includes `sgdisk --verify` and `pkgs.gptfdisk`.
  - `verify = false` omits `sgdisk --verify` and `pkgs.gptfdisk`.
  - `hydraBuildProduct = true` writes `$out/nix-support/hydra-build-products`.
  - `hydraBuildProduct = false` omits that write.

Run:

- `nixpkgs-fmt` on changed Nix files.
- `nix flake check --no-build`.
- `nix eval .#nixosModules.repart-image`.
- `nix eval .#nixosModules.repart-btrfs-esp`.
- `nix eval .#nixosModules.rockchip-uboot-repart`.
- `nix eval .#packages.x86_64-linux.repart-radxa-e20c.drvPath`.
- `nix eval .#packages.x86_64-linux.repart-fastrhino-r68s.drvPath`.
- `nix eval .#packages.x86_64-linux.sdimage-fly-gemini.drvPath`.
- `nix eval .#packages.x86_64-linux.sdimage-bigtreetech.drvPath`.
- `nix eval .#packages.x86_64-linux.sdimage-orangepi-3b.drvPath`.
- `nix eval .#packages.x86_64-linux.sdimage-panther-x2.drvPath`.
- `nix eval .#packages.x86_64-linux.sdimage-fastrhino-r68s.drvPath`.
- `nix eval .#packages.x86_64-linux.sdimage-radxa-e20c.drvPath`.
- `nix build .#packages.x86_64-linux.repart-radxa-e20c --dry-run`.

## Rollback

The change is limited to new modules, package wiring, docs, and checks. Before rollback, inspect `git diff --stat` to confirm the touched file set. Reverting those files restores the old inline repart image definitions; after rollback, rerun `nix flake check --no-build` to confirm the prior evaluation state is restored.
