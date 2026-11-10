{ icedosLib, lib, ... }:

{
  options.icedos.tweaks.gc =
    let
      inherit (icedosLib) mkBoolOption mkIntBetweenOption;
      inherit (lib) importTOML;
      inherit ((importTOML ./config.toml).icedos.tweaks.gc) coredump journal;

      mkDaysOption =
        name: default: description:
        mkIntBetweenOption {
          path = "icedos.tweaks.gc.${name}.days";
          source = ./config.toml;
          inherit default description;
        } 0 3650;
    in
    {
      coredump = {
        enable = mkBoolOption {
          default = coredump.enable;
          description = "Remove old systemd core dumps during icedos gc.";
        };

        days =
          mkDaysOption "coredump" coredump.days
            "Keep core dumps newer than this many days (0 = remove all).";
      };

      journal = {
        enable = mkBoolOption {
          default = journal.enable;
          description = "Remove old archived systemd journal files during icedos gc.";
        };

        days =
          mkDaysOption "journal" journal.days
            "Keep archived journals newer than this many days (0 = remove all archived).";
      };
    };

  outputs.nixosModules =
    { ... }:
    [
      (
        {
          config,
          lib,
          ...
        }:

        let
          inherit (config.icedos.tweaks.gc) coredump journal;
          inherit (lib) mkIf optionalString;

          coredumpClean = ''
            gc_section /var/lib/systemd/coredump "core dump"
            ${optionalString (coredump.days > 0) ''
              gc_note "Keeping core dumps newer than ''${DIM_GREEN}${toString coredump.days}''${NC}d"
            ''}
            gc_by_age ${toString coredump.days} /var/lib/systemd/coredump -maxdepth 1 -type f -name 'core.*'
          '';

          # Archived journals have an @ in the name or end in .journal~; active ones never match.
          journalClean = ''
            shopt -s nullglob
            for jdir in /var/log/journal/*/; do
              jdir="''${jdir%/}"
              gc_section "$jdir" "journal file"
              ${optionalString (journal.days > 0) ''
                gc_note "Keeping journals newer than ''${DIM_GREEN}${toString journal.days}''${NC}d"
              ''}
              gc_by_age ${toString journal.days} "$jdir" -maxdepth 1 -type f '(' -name '*@*.journal' -o -name '*.journal~' ')'
            done
            shopt -u nullglob
          '';
        in
        mkIf (coredump.enable || journal.enable) {
          icedos.system.gc.hooks.rootPostGc = [
            (optionalString coredump.enable coredumpClean + optionalString journal.enable journalClean)
          ];

          icedos.system.tips.list = [
            "icedos gc also removes old core dumps and archived journals."
          ];
        }
      )
    ];

  meta.name = "gc";
}
