# Repart Images

This repository exposes reusable NixOS modules for building `systemd-repart`
images. The intended downstream contract is:

- import a board module for kernel, device-tree, boot loader, and board image defaults;
- import `nixos-aarch64.nixosModules.repart-image` to get upstream repart image support plus `config.system.build.repartImage`;
- override the rootfs defaults when the product owns a different root layout.

## Default Board Images

Rockchip board modules in this repository set default repart image behavior. For
example, importing `radxa-e20c-kernel` or `fastrhino-r68s-kernel` together with
`repart-image` enables:

- `nixos-aarch64.repartImage.name`;
- the wrapped image output at `$out/sd-image/${config.image.baseName}.raw`;
- post-build raw U-Boot writes for `idbloader.img` and `u-boot.itb`;
- `image.repart.partitions."00-uboot"` as the 15 MiB reserved Rockchip loader partition;
- a vfat ESP firmware partition labeled `FIRMWARE`, mounted at `/boot/firmware`, containing `BOOTAA64.EFI` and the system UKI;
- a btrfs root partition labeled `NIXOS_ROOT`, mounted at `/`, with initrd systemd-repart growth enabled.

The U-Boot write commands use packages exposed by this flake overlay. Downstream
flakes should import `nixos-aarch64.nixosModules.apply-overlay` when they want
the board defaults to write the repository-provided U-Boot artifacts.

```nix
{
  description = "Radxa E20C repart image";

  inputs = {
    nixpkgs.url = "github:5aaee9/nixpkgs";
    nixos-aarch64.url = "github:your-org/nixos-aarch64";
  };

  outputs = { nixpkgs, nixos-aarch64, ... }:
    {
      nixosConfigurations.radxa-e20c-image = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";

        modules = [
          nixos-aarch64.nixosModules.apply-overlay
          nixos-aarch64.nixosModules.radxa-e20c-kernel
          nixos-aarch64.nixosModules.repart-image

          ({ ... }: {
            nixos-aarch64.repartImage.name = "custom-radxa-e20c";
          })
        ];
      };
    };
}
```

Build the wrapped image with:

```bash
nix build .#nixosConfigurations.radxa-e20c-image.config.system.build.repartImage
```

The resulting raw image is under `result/sd-image/custom-radxa-e20c.raw`.

The upstream repart image derivation remains available as `config.system.build.image`;
`system.build.repartImage` is the post-processed raw image intended for flashing
when this repository's wrapper behavior is wanted.

## Options

`nixos-aarch64.repartImage.name`

: Default value for `image.repart.name`.

`nixos-aarch64.repartImage.postBuildCommands`

: Shell commands run after the raw upstream image is copied. The variable `img`
  points at the copied image. Rockchip board modules use this to write U-Boot.

`nixos-aarch64.repartImage.verify`

: When true, the wrapper runs `sgdisk --verify "$img"`.

`nixos-aarch64.repartImage.hydraBuildProduct`

: When true, the wrapper emits Hydra build product metadata.

`nixos-aarch64.repartImage.btrfsEsp.enable`

: Enables this repository's default btrfs root plus ESP firmware layout.

`nixos-aarch64.repartImage.rockchipUboot.enable`

: Enables the reserved Rockchip U-Boot partition. This reserves GPT space; the
  raw loader bytes are written by `postBuildCommands`.

`nixos-aarch64.rockchipUbootRepart.label`

: GPT label for the reserved Rockchip loader partition.

## Custom Partition Layouts

If a downstream product only needs a different root filesystem shape, keep the
board and `repart-image` imports and override the root entries. The default ESP
firmware partition and Rockchip loader reservation remain in place because the
module defines them with `lib.mkDefault`.

```nix
({ config, ... }: {
  nixos-aarch64.repartImage = {
    name = "custom-radxa-e20c";
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_ROOT";
    fsType = "btrfs";
    neededForBoot = true;
  };

  systemd.repart.partitions."20-root" = {
    Type = "root-arm64";
    Format = "btrfs";
    Label = "NIXOS_ROOT";
    GrowFileSystem = true;
  };

  image.repart = {
    imageSize = "auto";
    mkfsOptions.btrfs = [ "--shrink" ];
    partitions."20-root" = {
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
})
```

If the product also owns the ESP or wants to remove the repository defaults
entirely, set `nixos-aarch64.repartImage.btrfsEsp.enable = false` and define all
boot, filesystem, runtime repart, and image repart entries locally:

```nix
({ config, ... }: {
  nixos-aarch64.repartImage = {
    name = "custom-radxa-e20c";
    btrfsEsp.enable = false;
  };

  image.repart = {
    partitions = {
      "10-esp" = {
        # Product-owned ESP contents.
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
```

`image.repart.partitions` describes the disk image at build time.
`systemd.repart.partitions` describes runtime repart behavior in the booted
system or initrd. Defining one does not automatically define the other.
