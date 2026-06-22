# Repart Images

This repository exposes reusable NixOS modules for building downstream
`systemd-repart` images. Board modules configure boot and hardware behavior;
image modules configure how an image is produced. Downstream products should
combine those pieces and own their own partition layout.

## Module Responsibilities

Import `nixos-aarch64.nixosModules.repart-image` for image construction. It
imports the upstream NixOS repart image modules, leaves
`config.system.build.image` available, and adds
`config.system.build.repartImage` as this repository's wrapped image output.
The wrapper copies the upstream raw image to:

```text
$out/sd-image/${config.image.baseName}.raw
```

It can then run `nixos-aarch64.repartImage.postBuildCommands`, verify the GPT
with `sgdisk --verify`, and emit Hydra build product metadata.

Import a board module, such as
`nixos-aarch64.nixosModules.radxa-e20c-kernel`, for board-specific kernel,
device-tree, initrd, and boot-loader settings. Board modules must stay usable as
normal NixOS modules; they should not define arbitrary image layouts, `sdImage`
options, root partitions, or downstream product data partitions.

Import `nixos-aarch64.nixosModules.repart-btrfs-esp` only when the repository's
default simple layout is wanted. That layout owns a btrfs root partition mounted
from `/dev/disk/by-label/NIXOS_ROOT` and a vfat ESP mounted at
`/boot/firmware` from `/dev/disk/by-label/FIRMWARE`.

Import `nixos-aarch64.nixosModules.rockchip-uboot-repart` when a Rockchip board
needs raw loader writes into the image. This module only reserves the
Rockchip/U-Boot GPT partition, `image.repart.partitions."00-uboot"`, using the
repository's custom partition type, 15 MiB size, and no padding. It does not
define root, ESP, or data partitions.

## Partition Ownership

Downstream systems should define their own `image.repart.partitions` entries for
root, ESP, data, recovery, or product-specific layouts. The reusable modules are
split so a product can reuse board boot/kernel support without inheriting this
repository's default image shape.

Use `nixos-aarch64.repartImage.name` to set the image name, or override upstream
`image.repart.name` / `image.baseName` directly when needed. Build the wrapped
image through:

```bash
nix build .#nixosConfigurations.<name>.config.system.build.repartImage
```

The upstream image derivation remains available at
`config.system.build.image`; `system.build.repartImage` is the post-processed
raw image intended for flashing when this repository's wrapper behavior is
wanted.

## Build-Time and Runtime Repart

`image.repart.partitions` describes the disk image at build time. These entries
decide what partitions are created in the artifact and what files or store paths
are copied into them.

`systemd.repart.partitions` describes runtime repart behavior. These entries are
used by systemd-repart in the booted system or initrd, for example to grow a
root partition on first boot. Defining an image partition does not automatically
define runtime growth behavior, and runtime repart settings do not by themselves
put a partition into the built image.

For the default btrfs/ESP layout, `/boot/firmware` is mounted with `nofail` and
`noauto`. The ESP contents are produced into the image during the build, so the
running system should not require the ESP to be mounted for normal operation or
fail boot if it is unavailable. Mount it explicitly only when updating or
inspecting ESP contents.

## Custom Downstream Example

This example builds a Radxa E20C image with downstream-owned partition layout. It
imports the Radxa board module, the generic repart image wrapper, and the
Rockchip reserved U-Boot partition module, then defines custom ESP and root
partitions locally.

```nix
{
  description = "Custom Radxa E20C repart image";

  inputs = {
    nixpkgs.url = "github:5aaee9/nixpkgs";
    nixos-aarch64.url = "github:your-org/nixos-aarch64";
  };

  outputs = { self, nixpkgs, nixos-aarch64, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.radxa-e20c-image = nixpkgs.lib.nixosSystem {
        inherit system;

        modules = [
          nixos-aarch64.nixosModules.radxa-e20c-kernel
          nixos-aarch64.nixosModules.repart-image
          nixos-aarch64.nixosModules.rockchip-uboot-repart

          ({ config, lib, pkgs, ... }: {
            nixos-aarch64.repartImage = {
              name = "custom-radxa-e20c";
              postBuildCommands = ''
                dd if=${nixos-aarch64.packages.${system}.radxa-e20c-uboot}/idbloader.img \
                  of="$img" seek=64 conv=notrunc status=none
                dd if=${nixos-aarch64.packages.${system}.radxa-e20c-uboot}/u-boot.itb \
                  of="$img" seek=16384 conv=notrunc status=none
              '';
            };

            fileSystems."/" = {
              device = "/dev/disk/by-label/NIXOS_ROOT";
              fsType = "btrfs";
              neededForBoot = true;
            };

            fileSystems."/boot/firmware" = {
              device = "/dev/disk/by-label/FIRMWARE";
              fsType = "vfat";
              options = [ "nofail" "noauto" ];
            };

            boot.supportedFilesystems = lib.mkForce [ "vfat" "btrfs" ];
            boot.initrd.supportedFilesystems = lib.mkForce [ "vfat" "btrfs" ];
            boot.initrd.systemd.enable = true;
            boot.initrd.systemd.repart.enable = true;

            systemd.repart.partitions."20-root" = {
              Type = "root-arm64";
              Format = "btrfs";
              Label = "NIXOS_ROOT";
              GrowFileSystem = true;
            };

            image.repart = {
              imageSize = "auto";
              mkfsOptions.btrfs = [ "--shrink" ];

              partitions = {
                "10-esp" = {
                  contents = {
                    "/EFI/BOOT/BOOTAA64.EFI".source =
                      "${config.systemd.package}/lib/systemd/boot/efi/systemd-bootaa64.efi";
                    "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
                      "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
                  };
                  repartConfig = {
                    Type = "esp";
                    Format = "vfat";
                    Label = "FIRMWARE";
                    SizeMinBytes = "128M";
                    SizeMaxBytes = "128M";
                    PaddingMinBytes = "0";
                  };
                };

                "20-root" = {
                  storePaths = [ config.system.build.toplevel ];
                  repartConfig = {
                    Type = "root-arm64";
                    Format = "btrfs";
                    Label = "NIXOS_ROOT";
                    SizeMinBytes = "5G";
                    PaddingMinBytes = "0";
                    GrowFileSystem = true;
                  };
                };
              };
            };
          })
        ];
      };
    };
}
```

Build the image with:

```bash
nix build .#nixosConfigurations.radxa-e20c-image.config.system.build.repartImage
```

The resulting raw image is under `result/sd-image/custom-radxa-e20c.raw`.
