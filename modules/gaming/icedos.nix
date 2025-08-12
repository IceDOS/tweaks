{ ... }:

{
  outputs.nixosModules =
    { ... }:
    [
      {
        boot = {
          kernelModules = [ "ntsync" ];

          kernelParams = [
            "clearcpuid=514" # Disables UMIP which fixes certain games from crashing on launch
          ];

          kernel.sysctl = {
            "kernel.split_lock_mitigate" = 0; # Fixes some games from stuttering
            "vm.max_map_count" = 1048576; # Fixes crashes or start-up issues for games
          };
        };

        security.pam.loginLimits = [
          {
            domain = "*";
            type = "hard";
            item = "memlock";
            value = "2147483648";
          }

          {
            domain = "*";
            type = "soft";
            item = "memlock";
            value = "2147483648";
          }
        ];
      }
    ];

  meta.name = "gaming";
}
