{ icedosLib, ... }:

{
  outputs.nixosModules =
    { repoUrl, ... }:
    [
      (
        { config, ... }:

        let
          inherit (config) icedos;

          useCachyosZramProfile =
            icedosLib.hasModule {
              inherit config repoUrl;
              name = "cachyos";
            }
            && (icedos.tweaks.cachyos.useCachyosZramProfile or false);
        in
        {
          boot = {
            kernelParams = [
              "transparent_hugepage=always"
            ];

            kernel.sysctl = {
              "vm.page-cluster" = if useCachyosZramProfile then 0 else 1;

              "vm.compaction_proactiveness" = 0;
              "vm.page_lock_unfairness" = 1;
            };
          };

          system.activationScripts.sysfs.text = ''
            echo advise > /sys/kernel/mm/transparent_hugepage/shmem_enabled
            echo 0 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
          '';

          icedos.system.tips.list = [
            "Memory is handed out in bigger blocks, so heavy apps and games run faster."
            "The system skips background memory tidying that can cause short freezes."
            "When memory gets tight, apps wait less for their turn."
          ];
        }
      )
    ];

  meta.name = "kernel";
}
