{ ... }:

{
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
          inherit (config.boot.kernelPackages.kernel) version;
          inherit (lib) mapAttrs mkIf versionAtLeast;

          dmemSupported = versionAtLeast version "7.0";
          dmemcg-booster = pkgs.callPackage ./package.nix { };
        in
        mkIf dmemSupported {
          environment.systemPackages = [ dmemcg-booster ];

          systemd.services.dmemcg-booster-system = {
            description = "Service for enabling and controlling dmem cgroup limits for boosting foreground games, system-level";
            wantedBy = [ "multi-user.target" ];
            serviceConfig.ExecStart = "${dmemcg-booster}/bin/dmemcg-booster --use-system-bus";
          };

          home-manager.users = mapAttrs (_: _: {
            systemd.user.services.dmemcg-booster-user = {
              Unit.Description = "Service for enabling and controlling dmem cgroup limits for boosting foreground games, user-level";
              Install.WantedBy = [ "graphical-session-pre.target" ];
              Service.ExecStart = "${dmemcg-booster}/bin/dmemcg-booster";
            };
          }) config.icedos.users;
        }
      )
    ];

  meta.name = "dmem";
}
