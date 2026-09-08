{ icedosLib, lib, ... }:

{
  options.icedos.tweaks.cachyos =
    let
      inherit (icedosLib) mkBoolOption;
      inherit (lib) importTOML;
      inherit ((importTOML ./config.toml).icedos.tweaks.cachyos) useAdios useCachyosZramProfile;
    in
    {
      useCachyosZramProfile = mkBoolOption { default = useCachyosZramProfile; };
      useAdios = mkBoolOption { default = useAdios; };
    };

  outputs.nixosModules =
    { ... }:
    [
      (
        {
          config,
          lib,
          pkgs,
          ...
        }:

        let
          inherit (config.icedos.tweaks.cachyos) useAdios useCachyosZramProfile;
          inherit (lib) mkIf optionals;
        in
        {
          boot.kernelParams = [
            "nowatchdog"
            "zswap.enabled=0"
          ];

          # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/sysctl.d/70-cachyos-settings.conf
          boot.kernel.sysctl = {
            "fs.file-max" = 2097152;
            "kernel.kptr_restrict" = 2;
            "kernel.nmi_watchdog" = 0;
            "kernel.printk" = "3 3 3 3";
            "kernel.unprivileged_userns_clone" = 1;
            "net.core.netdev_max_backlog" = 4096;
            "vm.dirty_background_bytes" = 67108864;
            "vm.dirty_bytes" = 268435456;
            "vm.dirty_writeback_centisecs" = 1500;
            "vm.vfs_cache_pressure" = 50;
          };

          services.zram-generator = mkIf useCachyosZramProfile {
            enable = true;

            settings.zram0 = {
              compression-algorithm = "zstd";
              zram-size = "ram";
              swap-priority = "100";
              fs-type = "swap";
            };
          };

          services.udev.extraRules =
            let
              # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/udev/rules.d/99-cpu-dma-latency.rules
              cpuDmaLatencyRule = ''
                DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
              '';

              # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/udev/rules.d/30-zram.rules
              zramProfile =
                if useCachyosZramProfile then
                  ''
                    ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", SYSCTL{vm.swappiness}="150", \
                        RUN+="/bin/sh -c 'echo N > /sys/module/zswap/parameters/enabled'"
                  ''
                else
                  "";

              # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/udev/rules.d/69-hdparm.rules
              hddRule = ''
                ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", \
                    ATTRS{id/bus}=="ata", RUN+="${pkgs.hdparm}/bin/hdparm -B 254 -S 0 /dev/%k"
              '';

              # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/udev/rules.d/40-hpet-permissions.rules
              hpetRule = ''
                KERNEL=="rtc0", GROUP="audio"
                KERNEL=="hpet", GROUP="audio"
              '';

              # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/udev/rules.d/60-ioschedulers.rules
              ioRule = ''
                # HDD
                ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", \
                    ATTR{queue/scheduler}="bfq"

                # SSD
                ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", \
                    ATTR{queue/scheduler}="${if useAdios then "adios" else "mq-deadline"}"

                # NVMe SSD
                ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
                    ATTR{queue/scheduler}="${if useAdios then "adios" else "kyber"}"
              '';

              # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/udev/rules.d/50-sata.rules
              sataRule = ''
                ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", \
                  ATTR{link_power_management_supported}=="1", \
                  ATTR{link_power_management_policy}="max_performance"
              '';
            in
            ''
              ${cpuDmaLatencyRule}
              ${zramProfile}
              ${hddRule}
              ${hpetRule}
              ${ioRule}
              ${sataRule}
            '';

          services.journald.settings.Journal.extraConfig = "SystemMaxUse=50M";

          system.activationScripts.sysfs.text = ''
            echo 409 > /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none
          '';

          services.ananicy = {
            enable = true;
            package = pkgs.ananicy-cpp;
            rulesProvider = pkgs.ananicy-rules-cachyos;
          };

          services.irqbalance.enable = true;

          systemd.settings.Manager = {
            DefaultTimeoutStartSec = "15s";
            DefaultTimeoutStopSec = "10s";
            DefaultLimitNOFILE = "2048:2097152";
          };

          icedos.system.tips.list = [
            "Your system runs CachyOS tuning, so everyday use feels quicker."
            "The app you are using gets priority over background jobs, so it stays smooth."
            "Drives and disk links are set for speed instead of power saving."
            "Boot and shutdown wait less on slow services before moving on."
          ]
          ++ optionals useCachyosZramProfile [
            "Spare memory is compressed instead of written to disk, so your PC stays fast when RAM fills up."
            "Turn compressed memory off with [icedos.tweaks.cachyos] useCachyosZramProfile = false in config.toml."
          ]
          ++ optionals useAdios [
            "Your drives learn how long they actually take and order work to match, so the system stays responsive while the disk is busy."
          ];
        }
      )
    ];

  meta.name = "cachyos";
}
