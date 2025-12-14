{ ... }:

{
  outputs.nixosModules =
    { ... }:
    [
      (
        { pkgs, ... }:
        {
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

          services.udev.extraRules =
            let
              # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/udev/rules.d/99-cpu-dma-latency.rules
              cpuDmaLatencyRule = ''
                DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
              '';

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
                    ATTR{queue/scheduler}="mq-deadline"

                # NVMe SSD
                ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", \
                    ATTR{queue/scheduler}="none"
              '';

              # https://github.com/CachyOS/CachyOS-Settings/blob/master/usr/lib/udev/rules.d/50-sata.rules
              sataRule = ''
                ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", \
                  ATTR{link_power_management_policy}=="*", \
                  ATTR{link_power_management_policy}="max_performance"
              '';
            in
            ''
              ${cpuDmaLatencyRule}
              ${hddRule}
              ${hpetRule}
              ${ioRule}
              ${sataRule}
            '';

          services.journald.extraConfig = "SystemMaxUse=50M";

          system.activationScripts.sysfs.text = ''
            echo 409 > /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none
          '';

          services.ananicy = {
            enable = true;
            rulesProvider = pkgs.ananicy-rules-cachyos;
          };

          systemd.settings.Manager = {
            DefaultTimeoutStartSec = "15s";
            DefaultTimeoutStopSec = "10s";
            DefaultLimitNOFILE = "2048:2097152";
          };
        }
      )
    ];

  meta.name = "cachyos";
}
