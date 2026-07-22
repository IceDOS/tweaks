{
  dbus,
  fetchgit,
  pkg-config,
  rustPlatform,
}:

let
  # Pin refreshed by ./update.sh, which tracks main's HEAD (upstream never tags) and
  # copies the matching Cargo.lock in beside this file.
  source = builtins.fromJSON (builtins.readFile ./source.json);
in
rustPlatform.buildRustPackage {
  pname = "dmemcg-booster";
  inherit (source) version;

  src = fetchgit {
    url = "https://gitlab.steamos.cloud/holo/dmemcg-booster.git";
    inherit (source) rev hash;
  };

  cargoLock.lockFile = ./Cargo.lock;

  postPatch = ''
    ln -sf ${./Cargo.lock} Cargo.lock
  '';

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ dbus ];

  postInstall = ''
    install -Dm644 dmemcg-booster-system.service $out/lib/systemd/system/dmemcg-booster-system.service
    install -Dm644 dmemcg-booster-user.service $out/lib/systemd/user/dmemcg-booster-user.service

    substituteInPlace $out/lib/systemd/system/dmemcg-booster-system.service \
      --replace-fail "/usr/bin/dmemcg-booster" "$out/bin/dmemcg-booster"
    substituteInPlace $out/lib/systemd/user/dmemcg-booster-user.service \
      --replace-fail "/usr/bin/dmemcg-booster" "$out/bin/dmemcg-booster"
  '';
}
