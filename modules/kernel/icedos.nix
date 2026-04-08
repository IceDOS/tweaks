{ ... }:

{
  outputs.nixosModules =
    { ... }:
    [
      (
        { config, lib, ... }:

        let
          inherit (config) boot icedos;
          inherit (boot.kernelPackages.kernel) version;
          inherit (icedos) tweaks;
          inherit (lib) hasAttr versionAtLeast;

          pageClusterKey =
            if versionAtLeast version "6.19" then "vm.page-cluster" else "vm.page_cluster";
        in
        {
          boot = {
            kernelParams = [
              "transparent_hugepage=always"
            ];

            kernel.sysctl = {
              ${pageClusterKey} =
                if (hasAttr "tweaks" icedos && hasAttr "cachyos" tweaks && tweaks.cachyos.useCachyosZramProfile) then
                  0
                else
                  1;

              "vm.compaction_proactiveness" = 0;
              "vm.page_lock_unfairness" = 1;
            };
          };

          # More sysctl params to set
          system.activationScripts.sysfs.text = ''
            echo advise > /sys/kernel/mm/transparent_hugepage/shmem_enabled
            echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
          '';
        }
      )
    ];

  meta.name = "kernel";
}
