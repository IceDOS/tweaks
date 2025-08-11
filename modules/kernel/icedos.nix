{ ... }:

{
  outputs.nixosModules =
    { ... }:
    [
      {
        boot = {
          kernelParams = [
            "transparent_hugepage=always"
          ];

          kernel.sysctl = {
            "page-cluster" = 1;
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
    ];

  meta.name = "kernel";
}
