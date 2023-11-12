{ name, config, pkgs, lib, inputs, ... }:
let
  machine-config = lib.getAttr name {
    moxps = [
      {
        imports = [
          (import "${inputs.nixos-hardware}/common/cpu/intel")
          (import "${inputs.nixos-hardware}/common/cpu/intel/kaby-lake")
          (import "${inputs.nixos-hardware}/common/pc/laptop")  # tlp.enable = true
          # (import "${inputs.nixos-hardware}/common/pc/laptop/acpi_call.nix")  # tlp.enable = true
          (import "${inputs.nixos-hardware}/common/pc/laptop/ssd")
          inputs.nixpkgs.nixosModules.notDetected
        ];
      
        # from nixos-hardware
        boot.loader.systemd-boot.enable = true;
        boot.loader.systemd-boot.configurationLimit = 10;
        boot.loader.efi.canTouchEfiVariables = false;  # disabled after a boot or two to prevent usage on that kind of ram
        services.thermald.enable = true; 
      
        # from initial config and other webresources
        boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
        boot.kernelModules = [ "kvm-intel" ];
        boot.kernelParams = [ "acpi_rev_override=5" "i915.enable_guc=2" "pcie_aspm=off" ];  # "nouveau.modeset=0" ];  # 5,6,1 doesn't seem to make a difference. pcie_aspm=off might be required to avoid freezes
        
        # OpenGL accelerateion
        # nixpkgs.config.packageOverrides = pkgs: {
        #   vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
        # };
        # hardware.opengl = {
        #   enable = true;
        #   driSupport = true;
        #   extraPackages = with pkgs; [
        #     intel-media-driver # LIBVA_DRIVER_NAME=iHD <- works for VLC
        #     vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        #     vaapiVdpau
        #     libvdpau-va-gl
        #   ];
        # };
      
      
        nix.maxJobs = lib.mkDefault 8;
      
        # TODO enable and check
        # services.undervolt = {
        #   enable = true;
        #   coreOffset = 0;
        #   gpuOffset = 0;
        #   # coreOffset = -125;
        #   # gpuOffset = -75;
        # };
        powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
        powerManagement.enable = true;
      
      }
      {
        system.nixos.tags = [ "with-intel" ];
        services.xserver.videoDrivers = [ "intel" ];  # modesetting didn't help
        hardware.nvidiaOptimus.disable = true;
        boot.blacklistedKernelModules = [ "nouveau" "nvidia" ];  # bbswitch
        
        # https://github.com/NixOS/nixpkgs/issues/94315 <- from here. bugfix for this: https://discourse.nixos.org/t/update-to-21-05-breaks-opengl-because-of-dependency-on-glibc-2-31/14218 note, that there are multiple occurences of this
        # hardware.opengl.package = pkgs.nixpkgs-2009.mesa_drivers;
        services.xserver = {
          displayManager = {
            lightdm.enable = false;
            gdm.enable = true;
          };
        };
      }
      {
        fileSystems."/" =
          { device = "/dev/disk/by-uuid/8f0a4152-e9f1-4315-8c34-0402ff7efff4";
            fsType = "btrfs";
          };
      
        fileSystems."/boot" =
          { device = "/dev/disk/by-uuid/A227-1A0D";
            fsType = "vfat";
          };
      
        swapDevices =
          [ { device = "/dev/disk/by-uuid/9eca5b06-730e-439f-997b-512a614ccce0"; }
          ];
      
      
        boot.initrd.luks.devices = {
          cryptkey.device = "/dev/disk/by-uuid/ccd19ab7-0e4d-4df4-8912-b87139de56af";
          cryptroot = {
            device="/dev/disk/by-uuid/88242cfe-48a1-44d2-a29b-b55e6f05d3d3";
            keyFile="/dev/mapper/cryptkey";
            };
          cryptswap = {
            device="/dev/disk/by-uuid/f6fa3573-44a9-41cc-bab7-da60d21e27b3";
            keyFile="/dev/mapper/cryptkey";
          };
        };
      }
      {
      # 3.5" HDD in fast-swappable case
        fileSystems."/mnt/hdd3tb" =
          { device = "/dev/disk/by-uuid/f6037d88-f54a-4632-bd9f-a296486fc9bc";
            fsType = "ext4";
            options = [ "nofail" ];
          };
      # 2.5" SSD ugreen
        fileSystems."/mnt/sdd2tb" =
          { device = "/dev/disk/by-uuid/44d8f482-0ab4-4184-8941-1cf3969c298c";
            fsType = "ext4";
            options = [ "nofail" ];
          };
      }
      {
        services.xserver.libinput = {
          enable = true;
          touchpad.accelSpeed = "0.7";
        };
        services.xserver.displayManager.lightdm.greeters.gtk.cursorTheme = {
          name = "Vanilla-DMZ";
          package = pkgs.vanilla-dmz;
          size = 128; # was 64
        };
        environment.variables.XCURSOR_SIZE = "64";
      }
      {
        musnix = {
          # Find this value with `lspci | grep -i audio` (per the musnix readme).
          # PITFALL: This is the id of the built-in soundcard.
          #   When I start using the external one, change it.
          soundcardPciId = "00:1f.3";
        };
      }
      {
        networking = {
          hostName = "moxps";
          useDHCP = false;
          interfaces.eth0.useDHCP = true;
          wireless.enable = false; 
          networkmanager.enable = true;
          nat = {  # NAT
            enable = true;
            externalInterface = "wlan0";
            internalInterfaces = [ "wg0" ];
          };
          firewall.allowedUDPPorts = [ 51820 ];
          firewall.allowedTCPPorts = [ 51821 8384 21 5000 ];  # syncthing as well, and FTP; and 5000 for vispr
        };
        
        services.nscd.enable = true;
        systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
      
        services.openssh = {
          enable = true;
          permitRootLogin = "yes";
          passwordAuthentication = true;
        };
      }
      {
        networking.wireguard.interfaces = {
          # "wg0" is the network interface name. You can name the interface arbitrarily.
          wg0 = {
            # Determines the IP address and subnet of the server's end of the tunnel interface.
            ips = [ "10.100.0.1/24" ];
      
            # The port that WireGuard listens to. Must be accessible by the client.
            listenPort = 51820;
      
            # This allows the wireguard server to route your traffic to the internet and hence be like a VPN
            # For this to work you have to set the dnsserver IP of your router (or dnsserver of choice) in your clients
            postSetup = ''
              ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
            '';
      
            # This undoes the above command
            postShutdown = ''
              ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.100.0.0/24 -o eth0 -j MASQUERADE
            '';
      
            # Path to the private key file.
            #
            # Note: The private key can also be included inline via the privateKey option,
            # but this makes the private key world-readable; thus, using privateKeyFile is
            # recommended.
            privateKeyFile = "/home/moritz/.wireguard/private_key";
      
            peers = [
              # List of allowed peers.
              { # Feel free to give a meaning full name
                # Public key of the peer (not a file path).
                publicKey = "jt+CtENSgKth7oXAmbb/jEyhtovwIz1RJIp5eWXIkz8=";
                # List of IPs assigned to this peer within the tunnel subnet. Used to configure routing.
                allowedIPs = [ "10.100.0.2/32" ];
              }
            ];
          };
        };
      }
      {
        services.ddclient = {
          enable = true;
          domains = [ "moritzs.duckdns.org" ];
          protocol = "duckdns";
          server = "www.duckdns.org";
          username = "nouser";
          passwordFile = "/root/duckdns_password";
        };
      
      }
      {
        # FTP server
        services.vsftpd = {
          enable = false;
      #   cannot chroot && write
      #    chrootlocalUser = true;
          writeEnable = true;
          localUsers = true;
          userlist = [ "moritz" ];
          anonymousUserHome = "/mnt/hdd3tb/ftp_anon/";
          userlistEnable = true;
          anonymousUser = true;
          anonymousUploadEnable = true;
          anonymousMkdirEnable = true;
        };
        # networking.firewall.allowedTCPPorts = [ 21 ]; # defined elsewhere
        services.vsftpd.extraConfig = ''
      	  pasv_enable=Yes
      	  pasv_min_port=51000
      	  pasv_max_port=51800
      	  '';
        networking.firewall.allowedTCPPortRanges = [ { from = 51000; to = 51800; } ];
      }
      {
        services.node-red = {
          enable = true;
          openFirewall = true;
          withNpmAndGcc = true;
        };
      }
      {
        config.virtualisation.oci-containers.containers = {
          deconz = {
            image = "deconzcommunity/deconz";
            ports = [ "0.0.0.0:8124:80" "0.0.0.0:8125:443" ];
            extraOptions = [ "--device=/dev/ttyUSB0:/dev/ttyUSB0:rwm"  "--expose" "5900" "--expose" "6080"];  # I think the exposes can be deleted
            volumes = [
             "/var/lib/deconz:/opt/deCONZ"
              "/etc/localtime:/etc/localtime:ro"
            ];
          };
        }; 
      }
      
      {
        virtualisation.oci-containers = {
          backend = "podman";
          containers.homeassistant = {
            volumes = [ "home-assistant:/config" ];
            environment.TZ = "Europe/Berlin";
            image = "ghcr.io/home-assistant/home-assistant:stable";  # Warning: if the tag does not change, the image will not be updated
            extraOptions = [
              "--network=host"
              "--device=/dev/ttyACM0:/dev/ttyACM0"  # Example, change this to match your own hardware
              "--device=/dev/ttyUSB0:/dev/ttyUSB0"  # Example, change this to match your own hardware
            ];
          };
        };
      }
      {
        networking.firewall.extraCommands = ''iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns'';
        services.samba = {
          enable = true;
          securityType = "user";
          openFirewall = true;
          extraConfig = ''
            workgroup = WORKGROUP
            wins support = yes
            server string = smbnix
            netbios name = smbnix
            security = user 
            #use sendfile = yes
            #max protocol = smb2
            hosts allow = 192.168.0.1/24  localhost
            hosts deny = 0.0.0.0/0
            guest account = nobody
            map to guest = bad user
          '';
          #shares = {
            #nas = {
              #"path" = "/mnt/sdd2tb";
              #"guest ok" = "yes";
              #"read only" = "no";
            #};
          #};
        };
      }
    ];
    mobook = [
      {
        imports = [
          # (import "${inputs.nixos-hardware}/apple/macbook-pro") # messes up the keyboard...
          (import "${inputs.nixos-hardware}/common/pc/laptop/ssd")
          (import "${inputs.nixos-hardware}/common/pc/laptop")  # tlp.enable = true
          (import "${inputs.nixos-hardware}/common/cpu/intel")
          #inputs.nixpkgs.modules.hardware.network.broadcom-43xx # <- using import vs not using import?
         #  <nixpkgs/nixos/modules/hardware/network/broadcom-43xx.nix> <- this is when using channels instead of flakes?
          inputs.nixpkgs.nixosModules.notDetected
        ];
        
        hardware.facetimehd.enable = true;
      
        # from https://wiki.archlinux.org/index.php/MacBookPro11,x#Powersave
        services.udev.extraRules = let
          # remove_script = pkgs.requireFile {
          #   name = "remove_ignore_usb_devices.sh";
          #   url = "https://gist.githubusercontent.com/anonymous/9c9d45c4818e3086ceca/raw/2aa42b5b7d564868ff089dc72445f24586b6c55e/gistfile1.sh";
          #   sha256 = "b2e1d250b1722ec7d3a381790175b1fdd3344e638882ac00f83913e2f9d27603";
          # };
          remove_script = ''
          # from https://gist.github.com/anonymous/9c9d45c4818e3086ceca
          logger -p info "$0 executed."
          if [ "$#" -eq 2 ];then
              removevendorid=$1
              removeproductid=$2
              usbpath="/sys/bus/usb/devices/"
              devicerootdirs=`ls -1 $usbpath`
              for devicedir in $devicerootdirs; do
                  if [ -f "$usbpath$devicedir/product" ]; then
                      product=`cat "$usbpath$devicedir/product"`
                      productid=`cat "$usbpath$devicedir/idProduct"`
                      vendorid=`cat "$usbpath$devicedir/idVendor"`
                      if [ "$removevendorid" == "$vendorid" ] && [ "$removeproductid" == "$productid" ];    then
                          if [ -f "$usbpath$devicedir/remove" ]; then
                              logger -p info "$0 removing $product ($vendorid:$productid)"
                          echo 1 > "$usbpath$devicedir/remove"
                              exit 0
                else
                              logger -p info "$0 already removed $product ($vendorid:$productid)"
                              exit 0
                fi
                      fi
                  fi
              done
          else
              logger -p err "$0 needs 2 args vendorid and productid"
              exit 1
          fi'';
          remove_script_local = pkgs.writeShellScript "remove_ignore_usb-devices_local.sh" remove_script; #(import ./remove_ignore_usb_devices.sh.nix); # (builtins.readFile remove_script)
        in
          ''
          # /etc/udev/rules.d/99-apple_cardreader.rules
          SUBSYSTEMS=="usb", ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="8406", RUN+="${remove_script_local} 05ac 8406"
          # /etc/udev/rules.d/99-apple_broadcom_bcm2046_bluetooth.rules
          SUBSYSTEMS=="usb", ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="8289", RUN+="${remove_script_local} 05ac 8289"
          SUBSYSTEMS=="usb", ATTRS{idVendor}=="0a5c", ATTRS{idProduct}=="4500", RUN+="${remove_script_local} 0a5c 4500"
      
          # Disable XHC1 wakeup signal to avoid resume getting triggered some time
          # after suspend. Reboot required for this to take effect.
          SUBSYSTEM=="pci", KERNEL=="0000:00:14.0", ATTR{power/wakeup}="disabled"
          '';
      
        systemd.services.disable-gpe06 = {
          description = "Disable GPE06 interrupt leading to high kworker";
          wantedBy = [ "multi-user.target" ];
          script = ''
            /run/current-system/sw/bin/bash -c 'echo "disable" > /sys/firmware/acpi/interrupts/gpe06'
          '';
          serviceConfig.Type = "oneshot";
        };
      
      
        boot.loader.systemd-boot.enable = true;
        boot.loader.systemd-boot.configurationLimit = 10;
        # boot.loader.efi.canTouchEfiVariables = true;
            
        # accelerateion
        # nixpkgs.config.packageOverrides = pkgs: {
        #   vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
        # };
        # hardware.opengl = {
        #   enable = true;
        #   extraPackages = with pkgs; [
        #     intel-media-driver # LIBVA_DRIVER_NAME=iHD
        #     vaapiIntel         # LIBVA_DRIVER_NAME=i965 (older but works better for Firefox/Chromium)
        #     vaapiVdpau
        #     libvdpau-va-gl
        #   ];
        # };
      
      
        boot.kernelModules = [ "kvm-intel" "wl" ];
        boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "usb_storage" "sd_mod" "usbhid" ];
        boot.extraModulePackages = [ config.boot.kernelPackages.broadcom_sta ];
      
        powerManagement.enable = true;
        powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
        
        services.mbpfan = {
          enable = true;
          lowTemp = 60;
          highTemp = 67;
          maxTemp = 84;
        };
      }
      {
        fileSystems."/boot" =
          { device = "/dev/disk/by-uuid/E64F-3226";
            fsType = "vfat";
          };
      
        swapDevices =
          [ { device = "/dev/disk/by-uuid/912c5850-5f71-4d15-8b69-1e0dad5718b0"; }
          ];
      
        fileSystems."/" =
          { device = "/dev/disk/by-uuid/73edc386-3f1a-46ff-9ae1-76a4fd6c0ea4";
            fsType = "btrfs";
          };
      
        boot.initrd.luks.devices = {
          cryptkey = {
            device = "/dev/disk/by-uuid/179ecdea-edd4-4dc5-b8c3-5ed760bc2a0d";
          };
          cryptroot = {
            device = "/dev/disk/by-uuid/623db0a5-d0e0-405a-88ae-b83a3d321656";
            keyFile = "/dev/mapper/cryptkey";
          };
          cryptswap = {
            device = "/dev/disk/by-uuid/da63991e-8edd-48db-bc4b-66fbc96917eb";
            keyFile = "/dev/mapper/cryptkey";
          };
        };
      }
      {
        services.xserver.libinput = {
          enable = true;
          touchpad.accelSpeed = "0.7";
        };
        # displayManager.lightdm.greeters.gtk.cursorTheme = {  # TODO if home manager cursor doesnt work
        #   name = "Vanilla-DMZ";
        #   package = pkgs.vanilla-dmz;
        #   size = 64;
        # };
      }
      {
        musnix = {
          # Find this value with `lspci | grep -i audio` (per the musnix readme).
          # PITFALL: This is the id of the built-in soundcard.
          #   When I start using the external one, change it.
          soundcardPciId = "00:1b.0";  # 00:1b.0 or 00:03.0
        };
      }
      {
        services.xserver.dpi = 200;
      }
    ];
    mopad = [
      {
        imports = [
          (import "${inputs.nixos-hardware}/lenovo/thinkpad/p1/3th-gen")
          (import "${inputs.nixos-hardware}/lenovo/thinkpad/p1/3th-gen/nvidia.nix")
          (import "${inputs.nixos-hardware}/common/gpu/nvidia/prime.nix")  # default: offload
          inputs.nixpkgs.nixosModules.notDetected
        ];
      
        # hardware.nvidia.modesetting.enable = true;
        # hardware.opengl.driSupport32Bit = true;
        # hardware.opengl.enable = true;
        # services.xserver.videoDrivers = [ "nvidia" ];
        # hardware.bumblebee.enable = false;
        
        services.hardware.bolt.enable = true;
        hardware.nvidia.powerManagement.enable = true;
        hardware.nvidia.powerManagement.finegrained = true;
        hardware.nvidia.prime = {
          # Bus ID of the Intel GPU.
          intelBusId = lib.mkDefault "PCI:0:2:0";
          # Bus ID of the NVIDIA GPU.
          nvidiaBusId = lib.mkDefault "PCI:1:0:0";
          
        };
      
        specialisation = {
          sync-gpu.configuration = {
            system.nixos.tags = [ "sync-gpu" ];
            hardware.nvidia.prime.offload.enable = lib.mkForce false;
            hardware.nvidia.prime.sync.enable = lib.mkForce true;
            hardware.nvidia.powerManagement.finegrained = lib.mkForce false;
            hardware.nvidia.powerManagement.enable = lib.mkForce false;
          };
        };
      
        environment.systemPackages = [ pkgs.linuxPackages.nvidia_x11 ];
        boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod" "sdhci_pci" ];
        # boot.blacklistedKernelModules = [ "nouveau" "nvidia_drm" "nvidia_modeset" "nvidia" ];
        boot.initrd.kernelModules = [ ];
        boot.kernelModules = [ "kvm-intel" ];
        boot.extraModulePackages = [ ];
      
        fileSystems."/" =
          { device = "/dev/disk/by-uuid/aed145a9-e93a-428b-be62-d3220fb1ab0f";
            fsType = "ext4";
          };
      
        fileSystems."/boot" =
          { device = "/dev/disk/by-uuid/F1D8-DA4A";
            fsType = "vfat";
          };
      
        # Use the systemd-boot EFI boot loader.
        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;
        swapDevices =
          [ { device = "/dev/disk/by-uuid/a048e8ec-3daa-4430-86ad-3a7f5e9acd91"; }
          ];
      
        powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
        hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
        # high-resolution display
      
        services.xserver = {
          enable = true;
          displayManager = {
            lightdm.enable = true;
            # gdm.enable = true;
          };
          libinput = {
            enable = true;
            touchpad.accelSpeed = "0.7";
      
            # disabling mouse acceleration
            # mouse = {
            #   accelProfile = "flat";
            # };
      
            # # disabling touchpad acceleration
            # touchpad = {
            #   accelProfile = "flat";
            # };
          };
        };
      }
      
      
      {
        networking.firewall.extraCommands = ''iptables -t raw -A OUTPUT -p udp -m udp --dport 137 -j CT --helper netbios-ns'';
        services.gvfs.enable = true;
        services.samba = {
          enable = true;
          securityType = "user";
          openFirewall = true;
          extraConfig = ''
            workgroup = WORKGROUP
            wins support = no
            wins server = 192.168.1.10
            server string = smbnix
            netbios name = smbnix
            security = user 
            #use sendfile = yes
            #max protocol = smb2
            hosts allow = 192.168.  localhost
            hosts deny = 0.0.0.0/0
            guest account = nobody
            map to guest = bad user
          '';
          shares = {
            # public = {
            #   path = "/mnt/Shares/Public";
            #   browseable = "yes";
            #   "read only" = "no";
            #   "guest ok" = "yes";
            #   "create mask" = "0644";
            #   "directory mask" = "0755";
            #   "force user" = "username";
            #   "force group" = "groupname";
            # };
            moritz = {
              path = "/home/moritz/";
              browseable = "yes";
              "read only" = "no";
              "guest ok" = "no";
              "create mask" = "0644";
              "directory mask" = "0755";
              "force user" = "moritz";
              "force group" = "users";
            };
          };
        };
      }
      {
        systemd.services.fix-enter-iso3 = {
          script = ''
            /run/current-system/sw/bin/setkeycodes 0x1c 58  # enter 
            /run/current-system/sw/bin/setkeycodes 0x2b 28  # enter
            /run/current-system/sw/bin/setkeycodes e038 86 # map alt gr to less than/greater than international key. should fix some issues in browser-based excel etc.
          '';
          wantedBy = [ "multi-user.target" ];
        };
      }
      {
        services.xserver.dpi = 140;  # was 130, 
      }
      {
        environment.systemPackages = [ pkgs.steam-run pkgs.steam ];
        hardware.opengl.driSupport32Bit = true;
        hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva vaapiIntel];
        hardware.pulseaudio.support32Bit = true;
        programs.steam.package = pkgs.steam.override {
          extraLibraries = pkgs: (with config.hardware.opengl;
            if pkgs.hostPlatform.is64bit
            then [ package ] ++ extraPackages
            else [ package32 ] ++ extraPackages32)
            ++ [ pkgs.libxcrypt ];
        };
      
      }
    ];
  };
  # nur-no-pkgs = import (builtins.fetchTarball {
  #   url = "https://github.com/nix-community/NUR/archive/master.tar.gz";
  #   sha256 = "10dq8abmw30lrpwfg7yb1zn6fb5d2q94yhsvg6dwcknn46nilbxs";
  # }) {
  #     nurpkgs = pkgs;
  #     inherit pkgs;
  #     repoOverrides = {
  #       moritzschaefer = import /home/moritz/Projects/nur-packages;
  #     };
  #   };
in
{
  # disabledModules = [ "services/printing/cupsd.nix" ]; 
  imports = [
    # (import "${inputs.nixpkgs-local}/nixos/modules/services/printing/cupsd.nix")
    (import "${inputs.musnix}")
    {
    
      nixpkgs.config.allowUnfree = true;
      nixpkgs.config.allowBroken = true;

      # The NixOS release to be compatible with for stateful data such as databases.
      system.stateVersion = "20.03";
    }

    {
      nix = {
        package = pkgs.nixFlakes;
        extraOptions = ''
          experimental-features = nix-command flakes
        '';
      };
    }
    {
      environment.systemPackages = [ pkgs.nixos-option ];
    }
    {
      nix = {
        settings = {
          substituters = [
            "https://nix-community.cachix.org"
            "https://cache.nixos.org/"
          ];
          trusted-public-keys = [
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          ];
        };
      };
    }
    {
    nix.nixPath = [
        "nixpkgs=${inputs.nixpkgs}"
      ];
    }
    {
      users.users.moritz = {
        isNormalUser = true;
        uid = 1000;
        extraGroups = [ "users" "wheel" "input" ];
        initialPassword = "HelloWorld";
      };
    }
    {
      environment.systemPackages = [
        pkgs.home-manager
      ];
    }
    {
      hardware.bluetooth.enable = true;
      hardware.bluetooth.powerOnBoot = false;
      services.blueman.enable = true;
      hardware.bluetooth.settings.General.Enable = "Source,Sink,Media,Socket";
    }
    {
      environment.systemPackages = [
        pkgs.ntfs3g
        pkgs.exfatprogs
      ];
    }
    {
      environment.systemPackages = [
        pkgs.sshfs
      ];
    
      fileSystems."/mnt/muwhpc" = {
        device = "//msc-smb.hpc.meduniwien.ac.at/mschae83";
        fsType = "cifs";
        options = [  # TODO requires credentials file /home/moritz/credentials.txt
          "username=mschae83"
          "domain=smb"
          "credentials=/home/moritz/muwhpc_credentials.txt"
          "vers=3"
          "sec=ntlmssp"
          "cache=strict"
          "noserverino"
          "nodev"
          "noexec"
          "nofail"
          "_netdev"
        ];
      };
    }
    {
      system.autoUpgrade.enable = true;
    }
    {
      systemd.timers.hibernate-on-low-battery = {
        wantedBy = [ "multi-user.target" ];
        timerConfig = {
          OnUnitActiveSec = "120";
          OnBootSec= "120";
        };
      };
      systemd.services.hibernate-on-low-battery =
        let
          battery-level-sufficient = pkgs.writeShellScriptBin
            "battery-level-sufficient" ''
            test "$(cat /sys/class/power_supply/BAT0/status)" != Discharging \
              || test "$(cat /sys/class/power_supply/BAT0/capacity)" -ge 5
          '';
        in
          {
            serviceConfig = { Type = "oneshot"; };
            onFailure = [ "hibernate.target" ];
            script = "${battery-level-sufficient}/bin/battery-level-sufficient";
          };
    }
    {
      nix.gc.automatic = true;
      nix.gc.options = "--delete-generations +12";
    }
    {
      security.pam.loginLimits = [{ # http://www.linux-pam.org/Linux-PAM-html/sag-pam_limits.html
        "domain" = "moritz";  # or group @users
        "type" = "-";
        "item" = "nice";
        "value" = "-18";
      }
      # {  # disabled for testing. check if everything works fine after reboot...
      #   "domain" = "moritz";  # or group @users
      #   "type" = "-";
      #   "item" = "priority";
      #   "value" = "-10";
      # }
      ];
    }
    {
      networking = {
        hostName = name;
    
        networkmanager = {
          enable = true;
          plugins = [
            pkgs.networkmanager-openconnect
            pkgs.networkmanager-vpnc
          ];
        };
    
        # disable wpa_supplicant
        wireless.enable = false;
      };
    
      users.users.moritz.extraGroups = [ "networkmanager" ];
    
      environment.systemPackages = [
        pkgs.openconnect
        pkgs.networkmanagerapplet
        pkgs.vpnc
        pkgs.vpnc-scripts
      ];
    }
    {
      services.avahi = {
        enable = true;
       allowInterfaces = [ "wlp9s0" "tun0" ];  # TODO how to add "all"?
        openFirewall = true;
        publish = {
          addresses = true;
          workstation = true;
          enable = true;
        };
        nssmdns = true;
      };
    }
    {
      hardware.pulseaudio = {
        enable = true;
        support32Bit = true;
        zeroconf.discovery.enable = true;
        systemWide = false;
        package = pkgs.pulseaudioFull; # .override { jackaudioSupport = true; };  # need "full" for bluetooth
      };
    
      environment.systemPackages = with pkgs; [ pavucontrol libjack2 jack2 qjackctl jack2Full jack_capture
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-base
      # gst_all_1.gst-plugins-ugly gst_all_1.gst-plugins-bad
      ffmpeg
      ];
    
      # services.jack = {
      #   jackd.enable = true;
      #   # support ALSA only programs via ALSA JACK PCM plugin
      #   alsa.enable = false;
      #   # support ALSA only programs via loopback device (supports programs like Steam)
      #   loopback = {
      #     enable = true;
      #     # buffering parameters for dmix device to work with ALSA only semi-professional sound programs
      #     #dmixConfig = ''
      #     #  period_size 2048
      #     #'';
      #   };
      # };
      # boot.kernelModules = [ "snd-seq" "snd-rawmidi" ];
    
      users.users.moritz.extraGroups = [ "audio" ];  # "jackaudio" 
    
      # from https://github.com/JeffreyBenjaminBrown/nixos-experiments/blob/6c4be545e2ec18c6d9b32ec9b66d37c59d9ebc1f/audio.nix
      security.sudo.extraConfig = ''
        moritz  ALL=(ALL) NOPASSWD: ${pkgs.systemd}/bin/systemctl
        '';
      musnix = {
        enable = true;
        alsaSeq.enable = false;
    
        # If I build with either of these, I get a PREEMPT error, much like
        #   https://github.com/musnix/musnix/issues/100
        # kernel.realtime = true;
        # kernel.optimize = true;
    
        # das_watchdog.enable = true;
          # I don't think this does anything without the realtime kernel.
    
        # magic to me
        rtirq = {
          # highList = "snd_hrtimer";
          resetAll = 1;
          prioLow = 0;
          enable = true;
          nameList = "rtc0 snd";
        };
      };
        
    
    }
    {
      services.printing.enable = true;
      services.printing.browsedConf = ''
        CreateIPPPrinterQueues All
      '';
      services.printing.drivers = with pkgs; [
        gutenprint
        gutenprintBin
        samsung-unified-linux-driver
        splix
        canon-cups-ufr2
        carps-cups
      ];
      services.system-config-printer.enable = true;
      environment.systemPackages = [
        pkgs.gtklp
      ];
    }
    {
      services.locate = {
        enable = true;
        localuser = "moritz";
      };
    }
    {
      services.dnsmasq = {
        enable = false;
    
        # These are used in addition to resolv.conf
        settings = {
          servers = [
            "8.8.8.8"
            "8.8.4.4"
          ];
          listenAddress = "127.0.0.1";
          cacheSize = 1000;
          noNegcache = true;
        };
      };
    }
    {
      services.syncthing = {
        enable = true;
        package = pkgs.unstable.syncthing;
        user = "moritz";
        dataDir = "/home/moritz/.config/syncthing";
        configDir = "/home/moritz/.config/syncthing";
        openDefaultPorts = true;
      };
    }
    {
      services.onedrive = {
        enable = true;
      };
    }
    {
      networking.firewall = {
        enable = true;
        allowPing = true;  # neede for samba
    
        connectionTrackingModules = [];
        autoLoadConntrackHelpers = false;
      };
    }
    {
      virtualisation.virtualbox.host.enable = true;
      virtualisation.docker.enable = true;
      virtualisation.docker.enableNvidia = true;
      
      systemd.enableUnifiedCgroupHierarchy = false;  # workaround https://github.com/NixOS/nixpkgs/issues/127146
      hardware.opengl.driSupport32Bit = true;
      environment.systemPackages = [
        pkgs.docker-compose
        pkgs.qemu_kvm
        pkgs.qemu
        # pkgs.nvtop # for nvidia
        pkgs.usbtop
        pkgs.xorg.xhost
      ];
    
      users.users.moritz.extraGroups = ["libvirtd" "docker"];  # the former is required for qemu I think 
    }
    {
      environment.systemPackages =
        let mount_external = pkgs.writeScriptBin "mount-external" ''
          #!${pkgs.stdenv.shell}
          sudo ${pkgs.cryptsetup}/bin/cryptsetup luksOpen /dev/disk/by-uuid/aeebfb90-65b5-4515-bf6e-001d0cfc8a40 encrypted-2tb
          sudo mount /dev/mapper/encrypted-2tb /mnt/encrypted
          '';
        umount_external = pkgs.writeScriptBin "umount-external" ''
          #!${pkgs.stdenv.shell}
          sudo umount /mnt/encrypted
          sudo ${pkgs.cryptsetup}/bin/cryptsetup luksClose encrypted-2tb
          '';
      in
         [ mount_external umount_external pkgs.borgbackup ];
    }
    {
      services.udev.packages = [ pkgs.android-udev-rules ];
      programs.adb.enable = true;
      users.users.moritz.extraGroups = ["adbusers"];
    }
    {
      services.fwupd.enable = true;
    }
    {
      environment.systemPackages = [
        pkgs.direnv
      ];
      programs.fish.shellInit = ''
        eval (direnv hook fish)
      '';
    
      services.lorri.enable = true;
    }
    {
      # services.udisks2.enable = true;
      services.devmon.enable = true;
    }
    {
      services.logind.extraConfig = ''
        HandlePowerKey=suspend
      '';
    }
    {
      # Enable cron service
      services.cron = {
        enable = true;
        systemCronJobs = [
          "* * * * 0      moritz    . /etc/profile; cd /home/moritz/wiki/; ${pkgs.git}/bin/git add .; ${pkgs.git}/bin/git commit -m 'Weekly checkpoint' 2>&1 >> /tmp/git_out"
        ];
      };
    }
    {
      environment.systemPackages = [
        pkgs.isync
      ];
    }
    {
      environment.systemPackages = [
        pkgs.msmtp
      ];
    }
    {
      environment.systemPackages = [
        pkgs.notmuch
      ];
    }
    {
      i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
    }
    {
      time.timeZone = "Europe/Berlin";
    }
    {
      security.sudo.extraConfig = ''
        Defaults        timestamp_timeout=120
      '';
    }
    {
      services.xserver = {
        # desktopManager.gnome3.enable = true;
        enable = true;
        displayManager = {
          startx.enable = false;
          autoLogin = {  # if errors, then disable again
            user = "moritz";
            enable = true;
          };
          defaultSession = "none+exwm";  # Firefox works more fluently with plasma5+exwm instead of "none+exwm". or does it??
        };
        windowManager = {
          exwm = {
            enable = true;
            extraPackages = epkgs: with epkgs; [ emacsql-sqlite pkgs.imagemagick pkgs.escrotum epkgs.vterm ];  # unfortunately, adding zmq and jupyter here, didn't work so I had to install them manually (i.e. compiling emacs-zmq)
            # I only managed to compile emacs-zmq once (~/emacs.d/elpa/27.1/develop/zmq-.../emacs-zmq.so). I just copied it from there to mobook
            enableDefaultConfig = false;  # todo disable and enable loadScript
            # careful, 'loadScript option' was merged from Vizaxo into my personal nixpkgs repo.
            loadScript = ''
              (require 'exwm)
              ;; most of it is now in .spacemacs.d/lisp/exwm.el
              (require 'exwm-systemtray)
              (require 'exwm-randr)
              ;; (setq exwm-randr-workspace-monitor-plist '(0 "eDP1" 1 "HDMI1" 2 "DP2" 3 "eDP1" 4 "HDMI1" 5 "DP2"))
              ;; (setq exwm-randr-workspace-monitor-plist '(0 "eDP1" 1 "eDP1" 2 "HDMI1" 3 "eDP1" 4 "eDP1" 5 "eDP1"))
              ;; (exwm-randr-enable)
              (exwm-systemtray-enable)
              (exwm-enable)
            '';
          };
          stumpwm.enable = false;
        };
        desktopManager = {
          xterm.enable = false;
          plasma5.enable = true;
          xfce = {
            enable = true;
            noDesktop= true;
            enableXfwm = true;
          };
        };
      };
      services.picom.enable = false;  # required for KDE connect but does not work anyways... might be responsible for weird/slow behaviour a couple of minutes after boot
    }
    {
      environment.systemPackages = [
        pkgs.wmname
        pkgs.xclip
        pkgs.escrotum
        pkgs.graphviz
      ];
    }
    {
      environment.systemPackages = with pkgs; [
        dunst
      ];
      systemd.user.services."dunst" = {
        enable = true;
        description = "";
        wantedBy = [ "default.target" ];
        serviceConfig.Restart = "always";
        serviceConfig.RestartSec = 2;
        serviceConfig.ExecStart = "${pkgs.dunst}/bin/dunst";
      };
    }
    {
      services.xserver.layout = "de,de,us";
      services.xserver.xkbVariant = "bone,,";
      services.xserver.xkbOptions= "lv5:rwin_switch_lock,terminate:ctrl_alt_bksp,altwin:swap_lalt_lwin";
    
      environment.systemPackages = [ pkgs.xorg.xmodmap ];
    
      # Use same config for linux console
      console.useXkbConfig = true;
    }
    {
      services.xserver.autoRepeatDelay = 150;
      services.xserver.autoRepeatInterval = 35;
    
      # Use same config for linux console
      console.useXkbConfig = true;
    }
    {
      # services.xserver.synaptics.enable = true;
      # services.xserver.synaptics.dev = "/dev/input/event7";
      # services.xserver.synaptics.tapButtons = false;
      # services.xserver.synaptics.buttonsMap = [ 1 3 2 ];
      # services.xserver.synaptics.twoFingerScroll = true;
      # services.xserver.synaptics.palmDetect = false;
      # services.xserver.synaptics.accelFactor = "0.001";
      # services.xserver.synaptics.additionalOptions = ''
      #   Option "SHMConfig" "on"
      #   Option "VertScrollDelta" "-100"
      #   Option "HorizScrollDelta" "-100"
      #   Option "Resolution" "370"
      # '';
    }
    {
      services.redshift = {
        enable = true;
        brightness.night = "1";
        temperature.night = 2800;
      };
    
      location.provider = "geoclue2";
      
      systemd.services.resume-redshift-restart = {
        description = "Restart redshift after resume to workaround bug not reacting after suspend/resume";
        wantedBy = [ "sleep.target" ];
        after = [ "systemd-suspend.service" "systemd-hybrid-sleep.service" "systemd-hibernate.service" ];
        script = ''
          /run/current-system/sw/bin/systemctl restart --machine=moritz@.host --user redshift
        '';
        serviceConfig.Type = "oneshot";
      };
    }
    {
      hardware.acpilight.enable = true;
      environment.systemPackages = [
        pkgs.acpilight
        pkgs.brightnessctl
      ];
      users.users.moritz.extraGroups = [ "video" ];
    }
    {
      fonts = {
        # fontDir.enable = true; # 21.03 rename
        fontDir.enable = true;
        enableGhostscriptFonts = false;
    
        fonts = with pkgs; [
          corefonts
          inconsolata
          dejavu_fonts
          source-code-pro
          ubuntu_font_family
          unifont
    
          # Used by Emacs
          # input-mono
          libertine
        ];
      };
    }
    {
      console.packages = [
        pkgs.terminus_font
      ];
      environment.variables = {
        GDK_SCALE = "1"; # this one impacts inkscape and only takes integers (1.3 would be ideal..., 2 is too much..)
        GDK_DPI_SCALE = "1.2"; # this only scales text and can take floats
        QT_SCALE_FACTOR = "1.2";  # this one impacts qutebrowser
        QT_AUTO_SCREEN_SCALE_FACTOR = "1.4";
      };
      console.font = "ter-132n";
    }
    {
      programs.ssh = {
        startAgent = true;
      };
      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = false;
        pinentryFlavor = "qt";
      };
    
      # is it no longer needed?
      
      # systemd.user.sockets.gpg-agent-ssh = {
      #   wantedBy = [ "sockets.target" ];
      #   listenStreams = [ "%t/gnupg/S.gpg-agent.ssh" ];
      #   socketConfig = {
      #     FileDescriptorName = "ssh";
      #     Service = "gpg-agent.service";
      #     SocketMode = "0600";
      #     DirectoryMode = "0700";
      #   };
      # };
    
      services.pcscd.enable = true;
    }
    {
      environment.systemPackages = with pkgs; [
        filezilla
      ];
    }
    {
      programs.kdeconnect.enable = true;
    }
    {
      services.minidlna = {
        enable = true;
        openFirewall = true;
        settings.media_dir= [ "/srv/minidlna/" ];
      };
    }
    {
      environment.systemPackages = with pkgs; [
        (pass.withExtensions (exts: [ exts.pass-otp ]))
        pinentry-curses
        pinentry-qt
        pinentry-emacs
        expect
      ];
      # services.keepassx.enable = true;
    }
    {
      environment.systemPackages = [
        pkgs.gwenview
        pkgs.filelight
        pkgs.shared-mime-info
      ];
    }
    {
      environment.pathsToLink = [ "/share" ];
    }
    {
      programs.browserpass.enable = true;
      environment.systemPackages = [
        pkgs.google-chrome
      ];
    }
    {
      environment.systemPackages = [
        (pkgs.firefox.override { extraNativeMessagingHosts = [ pkgs.passff-host ]; })
      ];
    }
    {
      environment.systemPackages =
        let wrapper = pkgs.writeScriptBin "qutebrowser-niced" ''
            #!${pkgs.stdenv.shell}
            exec nice --adjustment="-6" ${pkgs.qutebrowser}/bin/qutebrowser
            '';
        in
        [ pkgs.qutebrowser wrapper ];
      environment.variables.QUTE_BIB_FILEPATH = "/home/moritz/wiki/papers/references.bib";
    }
    {
      environment.systemPackages = [
        pkgs.zathura
      ];
    }
    {
      environment.systemPackages = with pkgs; [ xournalpp  masterpdfeditor qpdfview sioyek evince adobe-reader pdftk scribus ];  # unstable.sioyek fails tzz
    }
    {
      environment.systemPackages = [
        pkgs.weylus
      ];
      networking.firewall.allowedTCPPorts = [ 1701 9001 ];  # syncthing as well, and FTP; and 5000 for vispr
      users.groups.uinput = {};
      users.users.moritz.extraGroups = [ "uinput" ];
      services.udev.extraRules = ''
        KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
      '';
    }
    {
      programs.slock.enable = true;
    }
    {
      environment.systemPackages = [
        pkgs.xss-lock
      ];
    }
    {
      environment.systemPackages = with pkgs; [
        igv
      ];
    }
    {
      environment.systemPackages =
        let wrapper = pkgs.writeScriptBin "spotify-highres" ''
          #!${pkgs.stdenv.shell}
          exec ${pkgs.spotify}/bin/spotify --force-device-scale-factor=2
          '';
      in
         [ pkgs.spotify wrapper pkgs.playerctl ];
    }
    {
      services.tor.enable = false;
      services.tor.client.enable = false;
      environment.systemPackages = [ pkgs.tor-browser-bundle-bin ];
    }
    {
    
      environment.systemPackages = with pkgs; [
        #haskellPackages.pandoc
        # jabref
        nixpkgs-2009.pandoc
        nixpkgs-2009.haskellPackages.pandoc-crossref  # broken...
        nixpkgs-2009.haskellPackages.pandoc-citeproc  # broken...
        texlive.combined.scheme-full  # until 22.05, this installs an old version of ghostscript
      ];
    }
    {
      environment.systemPackages = [ pkgs.supercollider ];
    }
    {
       # virtualisation.virtualbox.host.enable = true;
       users.extraGroups.vboxusers.members = [ "moritz" ];
       nixpkgs.config.allowUnfree = true;
       virtualisation.virtualbox.host.enableExtensionPack = true;
    }
    {
      environment.systemPackages = with pkgs; [
        # qt5Full
        aria
        fd
        wmctrl
        nodejs
        nodePackages.npm
        mupdf
      ];
      environment.variables.QT_QPA_PLATFORM_PLUGIN_PATH = "${pkgs.qt5.qtbase.bin.outPath}/lib/qt-${pkgs.qt5.qtbase.version}/plugins";  # need to rerun 'spacemacs/force-init-spacemacs-env' after QT updates...
    }
    { 
      environment.systemPackages = [
        pkgs.davinci-resolve
      ];
    }
    {
      environment.systemPackages =
        with pkgs;
        let sparkleshare_fixed = sparkleshare.overrideAttrs ( oldAttrs: {
          postInstall = ''
            wrapProgram $out/bin/sparkleshare \
                --set PATH ${symlinkJoin {
                  name = "mono-path";
                  paths = [
                    coreutils
                    bash
                    git
                    git-lfs
                    glib
                    mono
                    openssh
                    openssl
                    xdg_utils
                  ];
                }}/bin \
                --set MONO_GAC_PREFIX ${lib.concatStringsSep ":" [
                  appindicator-sharp
                  gtk-sharp-3_0
                  webkit2-sharp
                ]} \
                --set LD_LIBRARY_PATH ${lib.makeLibraryPath [
                  appindicator-sharp
                  gtk-sharp-3_0.gtk3
                  webkit2-sharp
                  webkit2-sharp.webkitgtk
                ]}
          '';
          } ); in
        [
        betaflight-configurator
        miraclecast
        xcolor
        vlc
        aria
        jetbrains.pycharm-community
        obs-studio
        jmtpfs
        qbittorrent
        unstable.blender
        teams
        discord
        inkscape
        arandr
        dmenu
        # soulseekqt
        gnome3.cheese
        gnome3.gnome-screenshot
        sparkleshare_fixed 
        gnome3.gpaste
        autorandr
        libnotify
        feh
    
        # kdenlive  # fails in current unstable
        audacity
        ytmdesktop
        tdesktop # Telegram
        signal-cli # Signal
        signal-desktop # Signal
        unstable.zoom-us
        libreoffice
        wineWowPackages.stable
        # winetricks  # requires p7zip (which is unsafe...)
        gimp-with-plugins
    
        mplayer
        mpv
        smplayer
        lm_sensors
        tcl
        pymol
        ruby
    
        # Used by naga setup
        xdotool # required by eaf
      ];
    }
    {
      environment.systemPackages = [ pkgs.niv ];
    }
    {
      environment.systemPackages = [ pkgs.hugo ];
    }
    {
    services.flatpak.enable = true;
    }
    {
      environment.variables.EDITOR = "vim";
      environment.systemPackages = [
        pkgs.vim_configurable # .override { python3 = true; })
        pkgs.neovim
      ];
    }
    {
      environment.systemPackages = [
        pkgs.cudaPackages.cuda_nvcc
      ];
    }
    {
      # leads to trouble only..
      systemd.services.modem-manager.enable = false;
      systemd.services."dbus-org.freedesktop.ModemManager1".enable = false;
      
      services.udev.extraRules = ''
        # Atmel DFU
        ### ATmega16U2
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2fef", TAG+="uaccess"
        ### ATmega32U2
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2ff0", TAG+="uaccess"
        ### ATmega16U4
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2ff3", TAG+="uaccess"
        ### ATmega32U4
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2ff4", TAG+="uaccess"
        ### AT90USB64
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2ff9", TAG+="uaccess"
        ### AT90USB128
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="03eb", ATTRS{idProduct}=="2ffb", TAG+="uaccess"
        ### Pro Micro 5V/16MHz
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="1b4f", ATTRS{idProduct}=="9205", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
        ## dog hunter AG
        ### Leonardo
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="2a03", ATTRS{idProduct}=="0036", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
        ### Micro
        SUBSYSTEMS=="usb", ATTRS{idVendor}=="2a03", ATTRS{idProduct}=="0037", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
      '';
      environment.systemPackages = [ pkgs.qmk ];  # TODO might need unstable
    }
    {
      environment.systemPackages =
        let conda_shell_kernel_commands = pkgs.writeScript "guided_environment" ''
          #!${pkgs.stdenv.shell}
          conda activate ag_binding_diffusion
    
          LOG=/tmp/guided_environ_kernel_output
          SYMLINK=/tmp/guided_protein_diffusion_kernel.json
          if [ -L $SYMLINK ]; then
            echo "Warning: Removing symlink to old kernel."
            rm $SYMLINK
          fi
    
          # Redirect the output of the first command to the named pipe and run it in the background
          jupyter kernel --kernel=python 2> $LOG &
    
          PATTERN='/[.a-z0-9/\-]\+.json'
          while ! grep -q "$PATTERN" $LOG; do sleep 0.2; done
          target=$(grep -o $PATTERN $LOG)
          echo $target
          ln -s $target $SYMLINK
    
          wait
          rm $SYMLINK
        '';
        conda_shell_env_cmd = pkgs.writeScript "guided_environment" ''
          #!${pkgs.stdenv.shell}
          conda activate ag_binding_diffusion
          "$@"
        '';
        kernel_wrapper = pkgs.writeShellScriptBin "guided_prot_diff_kernel" ''
          /run/current-system/sw/bin/conda-shell ${conda_shell_kernel_commands}  
        '';  # TODO conda-shell should be provided via a nix variable
        repl_wrapper = pkgs.writeShellScriptBin "guided_prot_diff_repl" ''
          /run/current-system/sw/bin/conda-shell ${conda_shell_env_cmd} "python" "$@"
        '';  # TODO conda-shell should be provided via a nix variable
        cmd_wrapper = pkgs.writeShellScriptBin "guided_prot_diff_cmd" ''
          /run/current-system/sw/bin/conda-shell ${conda_shell_env_cmd} "$@"
        ''; # TODO conda-shell should be provided via a nix variable
      in [
        pkgs.conda kernel_wrapper repl_wrapper cmd_wrapper
      ];
    }
    {
      environment.systemPackages = [
        pkgs.rxvt_unicode
      ];
    }
    {
      fonts = {
        fonts = with pkgs; [
          powerline-fonts
          terminus_font
    
        ];
      };
    }
    {
      programs.fish.enable = true;
      users.defaultUserShell = pkgs.fish;
      
      environment.systemPackages = [
        pkgs.any-nix-shell
      ];
      programs.fish.promptInit = ''
        any-nix-shell fish --info-right | source
      '';
    }
    {
      environment.systemPackages = [
        pkgs.gitFull
        pkgs.gitg
        pkgs.git-lfs
        pkgs.git-filter-repo
      ];
    }
    {
      environment.systemPackages = [
        pkgs.tmux
        pkgs.python39Packages.powerline
      ];
    }
    {
      environment.systemPackages =
        let python = (with pkgs; python3.withPackages (python-packages: with python-packages;
          let opencvGtk = opencv4.override (old : { enableGtk2 = true; enableGStreamer = true; });
              eaf-deps = [
                # pyqt5 sip
                # pyqtwebengine
                epc lxml
                # eaf-file-browser
                qrcode
                # eaf-browser
                pysocks
                # eaf-pdf-viewer
                pymupdf
                # eaf-file-manager
                pypinyin
                # eaf-system-monitor
                psutil
                # eaf-markdown-previewer
                retry
                markdown
              ];
              orger-pkgs = [
                orger
                hpi
                pdfannots  # required for pdfs
                datasets  # for twint (twitter)
                twint
              ];
          in orger-pkgs ++ eaf-deps ++ [
          # gseapy
          pymol
          umap-learn
          icecream
          plotly
          pytorch
          # ignite
          # pytorch-lightning
          # pytorch-geometric
          python3
          black
          pandas
          XlsxWriter
          # opencvGtk
          openpyxl
          biopython
          scikitlearn
          wandb
          imageio
          matplotlib
          pyproj
          seaborn
          requests
          pillow
          ipdb
          isort
          tox
          tqdm
          xlrd
          pyyaml
          matplotlib-venn
          networkx
          statsmodels
          up-set-plot
          # jedi
          # json-rpc
          # service-factory
          debugpy
    
          fritzconnection
          # jupyter
          # jupyter_core
          powerline
          adjust-text
          # up-set-plot
          # moritzsphd
          tabulate
          # swifter
          gffutils
          # pyensembl  # fails due to serializable
          # pybedtools
          pybigwig
          xdg
          epc
          importmagic
          jupyterlab
          jupyter_console
          ipykernel
          pyperclip
          # scikit-plot
          # scikit-bio
          powerline
          python-lsp-server
          smogn
          docker
          absl-py
          hjson
          pygments
          # ptvsd
          ])); in with pkgs.python3Packages; [
        python  # let is stronger than with, which is why this installs the correct python (the one defined above)
        pkgs.rPackages.orca  # required for plotly
        pkgs.pipenv
        pip
        pkgs.nodePackages.pyright
        python-lsp-server
        selenium
        # pkgs.zlib
        #pkgs.zlib.dev
        # nur-no-pkgs.repos.moritzschaefer.python3Packages.cytoflow
      ];
      # Adding libstdc++ to LD_LIB_PATH to fix some python imports (https://nixos.wiki/wiki/Packaging/Quirks_and_Caveats) # TODO might not work anymore because of libgl?
      environment.variables.LD_LIBRARY_PATH = with pkgs; "$LD_LIBRARY_PATH:${stdenv.cc.cc.lib}/lib";  # for file libstdc++.so.6
    }
    {
      environment.systemPackages = with pkgs; [ clojure leiningen ];
    }
    {
      environment.systemPackages = with pkgs; [
        libGL
        zlib
        zstd
        gcc
        pkg-config
        autoconf
        clang-tools
      ];
    }
    {
      environment.systemPackages = with pkgs; [
        bedtools
      ];
    }
    {
      environment.systemPackages = [ pkgs.arduino ];
      users.users.moritz.extraGroups = [ "dialout" ];
    }
    {
      environment.systemPackages = with pkgs; [
        cookiecutter
        nix-index
        tmux
        unstable.gpu-burn
        gdrive
        tldr
        nmap
        sqlite
        gitAndTools.hub
        yt-dlp
        sshfs
        bash
        wget
        htop
        glances
        psmisc
        zip
        p7zip
        unzip
        unrar
        bind
        file
        which
        # utillinuxCurses
        powerstat
        pciutils
        silver-searcher
        ispell
        usbutils
        libv4l
        v4l-utils
        gparted
        # etcher
        powerline-fonts
        xsel
        tree
        gitAndTools.diff-so-fancy
        gitAndTools.git-hub
        # pypi2nix
        lsyncd
        gnupg
        imagemagick
        gdb
        ncdu
        mesa-demos
    
    
        patchelf
    
        cmake
        gnumake
    
      ];
      environment.variables.SNAKEMAKE_CONDA_PREFIX = "/home/moritz/.conda";
      # environment.variables.NPM_CONFIG_PREFIX = "$HOME/.npm-global";
      # environment.variables.PATH = "$HOME/.npm-global/bin:$PATH";
    }
  ] ++ machine-config;
}
