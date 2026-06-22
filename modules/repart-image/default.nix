{ config
, lib
, pkgs
, modulesPath
, ...
}:

let
  cfg = config.nixos-aarch64.repartImage;
  imagePath = "${config.system.build.image}/${config.image.filePath}";
  outputImage = "$out/sd-image/${config.image.baseName}.raw";
  nativeBuildInputs = lib.optional cfg.verify pkgs.gptfdisk;
  buildCommand = ''
    mkdir -p $out/sd-image
    img=${outputImage}
    install -m 0644 ${imagePath} "$img"

    ${cfg.postBuildCommands}

    ${lib.optionalString cfg.verify ''
      sgdisk --verify "$img"
    ''}
    ${lib.optionalString cfg.hydraBuildProduct ''
      mkdir -p $out/nix-support
      echo "file sd-image $img" >> $out/nix-support/hydra-build-products
    ''}
  '';
in
{
  imports = [
    "${modulesPath}/image/repart.nix"
    "${modulesPath}/system/boot/systemd/repart.nix"
  ];

  options.nixos-aarch64.repartImage = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "nixos-repart";
      description = "Default repart image name used when image.repart.name is not overridden.";
    };

    postBuildCommands = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Shell commands run after copying the raw repart image. The variable img points at the copied image.";
    };

    verify = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to verify the wrapped GPT image with sgdisk.";
    };

    hydraBuildProduct = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to emit Hydra build product metadata for the wrapped image.";
    };
  };

  config = {
    assertions = [
      {
        assertion = config.system.build ? image;
        message = "nixos-aarch64.repartImage requires upstream system.build.image from the repart image module.";
      }
      {
        assertion = config.image.extension == "raw";
        message = "nixos-aarch64.repartImage only supports raw uncompressed repart images.";
      }
    ];

    image.repart = {
      name = lib.mkDefault cfg.name;
      compression.enable = lib.mkDefault false;
    };

    system.build.repartImage = pkgs.runCommand config.image.baseName
      {
        inherit nativeBuildInputs;
        passthru = {
          inherit imagePath;
          inherit buildCommand nativeBuildInputs;
          nativeBuildInputPaths = map toString nativeBuildInputs;
          outputImage = "sd-image/${config.image.baseName}.raw";
          inherit (cfg) hydraBuildProduct postBuildCommands verify;
        };
      }
      buildCommand;
  };
}
