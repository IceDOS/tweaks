{ icedosLib, ... }:

{
  outputs.nixosModules =
    { repoUrl, ... }:
    [
      (
        { config, lib, ... }:

        let
          inherit (config) boot icedos;
          inherit (boot.kernelPackages.kernel) version;
          inherit (lib) versionAtLeast;

          useCachyosZramProfile =
            icedosLib.hasModule {
              inherit config repoUrl;
              name = "cachyos";
            }
            && (icedos.tweaks.cachyos.useCachyosZramProfile or false);

          pageClusterKey = if versionAtLeast version "6.19" then "vm.page-cluster" else "vm.page_cluster";
        in
        {
          boot = {
            kernelParams = [
              "transparent_hugepage=always"
            ];

            kernel.sysctl = {
              ${pageClusterKey} = if useCachyosZramProfile then 0 else 1;

              "vm.compaction_proactiveness" = 0;
              "vm.page_lock_unfairness" = 1;
            };
          };

          system.activationScripts.sysfs.text = ''
            echo advise > /sys/kernel/mm/transparent_hugepage/shmem_enabled
            echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
          '';
        }
      )
    ];

  meta.name = "kernel";
}
