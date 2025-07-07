{
  description = "Moritz's NixOS";

  # edition = 201909;

  inputs = {
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-25.05";
    };
    nixpkgs-unstable = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "master";
    };
    nixpkgs-moritz = {
      type = "github";
      # owner = "rasendubi";
      # repo = "nixpkgs";
      # ref = "melpa-2020-04-27";
      owner = "moritzschaefer";
      # repo = "nixpkgs-channels";
      repo = "nixpkgs";
      # rev = "246294708d4b4d0f7a9b63fb3b6866860ed78704";
      # ref = "nixpkgs-unstable";
      ref = "fix-libnvidia-container";
    };
    # nixpkgs-local = {
    #   url = "/home/moritz/Projects/nixpkgs/";
    # };

    nixos-hardware = {
      type = "github";
      owner = "NixOS";
      repo = "nixos-hardware";
    };
    nur = {
      url = github:nix-community/NUR;
    };
    agenix.url = "github:ryantm/agenix";
    apple-silicon = {
      type = "github";
      owner = "tpwrules";
      repo = "nixos-apple-silicon";
      # url = "github:tpwrules/nixos-apple-silicon";
      # this line prevents fetching two versions of nixpkgs:
      inputs.nixpkgs.follows = "nixpkgs";
      ref = "releasep2-2024-12-25";  # https://github.com/tpwrules/nixos-apple-silicon
    };
  };
  
# nixpkgs-local
  outputs = { self, nixpkgs, nixpkgs-moritz, nixpkgs-unstable, nixos-hardware, nur, agenix, apple-silicon }@inputs:
    let
      system-wrapper = name: if name == "moair" then "aarch64-linux" else "x86_64-linux";
      pkgs-wrapper = name: import nixpkgs {
        system = system-wrapper name;
        overlays = self.overlays;
        config = { allowUnfree = true;
                    allowBroken = true;
                    nvidia.acceptLicense = true;
                    permittedInsecurePackages = [
                      "adobe-reader-9.5.5"
                      "python3.11-youtube-dl-2021.12.17"
                      "qtwebkit-5.212.0-alpha4"
                      "openjdk-18+36"
                      "python-2.7.18.6"
                    ];
                    };
      };
    in {
      nixosConfigurations =
        let
          hosts = ["moxps" "mobook" "mopad" "moair"];
          mkHost = name:
            nixpkgs.lib.nixosSystem {
              system = system-wrapper name;
              modules = [
                { nixpkgs = { pkgs = (pkgs-wrapper name);  }; }
                (import ./nixos-config.nix)
                { nixpkgs.overlays = [ nur.overlays.default ]; }
                agenix.nixosModules.default
                {
                  environment.systemPackages = [ agenix.packages.${system-wrapper name}.default ];
                  age.identityPaths = [ "/home/moritz/.ssh/id_ed25519_agenix" ];
                }
              ];
              specialArgs = { inherit name inputs; };
            };
        in nixpkgs.lib.genAttrs hosts mkHost;

      # redundant
      packages.x86_64-linux =
        let
          mergePackages = nixpkgs.lib.foldr nixpkgs.lib.mergeAttrs {};
        in
          mergePackages [
            
          ];
      # redundant
      packages.aarch64-linux =
        let
          mergePackages = nixpkgs.lib.foldr nixpkgs.lib.mergeAttrs {};
        in
          mergePackages [
            
          ];

      overlays = [
        # (_self: _super: builtins.getAttr _super.system self.packages)  # this led to "infinite recursion" but it was actually not needed (weird!)
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable {
            system = prev.system;
            overlays = self.overlays; # .${system};
            config = { allowUnfree = true;  allowBroken = true; nvidia.acceptLicense = true; };
          };
          
         
          # mkNvidiaContainerPkg = { name, containerRuntimePath, configTemplate, additionalPaths ? [] }:
          #   let
          #     nvidia-container-runtime = pkgs.callPackage "${inputs.nixpkgs}/pkgs/applications/virtualization/nvidia-container-runtime" {
          #       inherit containerRuntimePath configTemplate;
          #     };
          #   in pkgs.symlinkJoin {
          #     inherit name;
          #     paths = [
          #       # (callPackage ../applications/virtualization/libnvidia-container { })
          #       (pkgs.callPackage "${inputs.nixpkgs-moritz}/pkgs/applications/virtualization/libnvidia-container" { inherit (pkgs.linuxPackages) nvidia_x11; })
          #       nvidia-container-runtime
          #       (pkgs.callPackage "${inputs.nixpkgs}/pkgs/applications/virtualization/nvidia-container-toolkit" {
          #         inherit nvidia-container-runtime;
          #       })
          #     ] ++ additionalPaths;
          #   };
          
          # nvidia-docker = pkgs.mkNvidiaContainerPkg {
          #   name = "nvidia-docker";
          #   containerRuntimePath = "${pkgs.docker}/libexec/docker/runc";
          #   # configTemplate = "${inputs.nixpkgs}/pkgs/applications/virtualization/nvidia-docker/config.toml";
          #   configTemplate = builtins.toFile "config.toml" ''
          #   disable-require = false
          #   #swarm-resource = "DOCKER_RESOURCE_GPU"
        
          #   [nvidia-container-cli]
          #   #root = "/run/nvidia/driver"
          #   #path = "/usr/bin/nvidia-container-cli"
          #   environment = []
          #   debug = "/var/log/nvidia-container-runtime-hook.log"
          #   ldcache = "/tmp/ld.so.cache"
          #   load-kmods = true
          #   #no-cgroups = false
          #   #user = "root:video"
          #   ldconfig = "@@glibcbin@/bin/ldconfig"
          #   '';
          #   additionalPaths = [ (pkgs.callPackage "${inputs.nixpkgs}/pkgs/applications/virtualization/nvidia-docker" { }) ];
          # };
          # mesa-pin = import inputs.mesa-pin {
          #   inherit system;
          #   overlays = self.overlays; # .${system};
          #   config = { allowUnfree = true; };
          # };
        })
        (_self: _super: { conda = _super.conda.override { extraPkgs = [ _super.libffi_3_3 _super.libffi _super.which _super.libxcrypt ]; }; })  # this is an overlay
        # TODO override R package  (openssl)
      ];

        # in nixpkgs.lib.genAttrs hosts mkHost;
    };
}
