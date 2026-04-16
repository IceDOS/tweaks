{
  dbus,
  fetchgit,
  pkg-config,
  rustPlatform,
}:

rustPlatform.buildRustPackage rec {
  pname = "dmemcg-booster";
  version = "0.1.2";

  src = fetchgit {
    url = "https://gitlab.steamos.cloud/holo/dmemcg-booster.git";
    rev = "79de901c077fedf2b3be53b460e4be8c16eaf020";
    hash = "sha256-qETBTccMJmB5IJPBK1sLTUdtpPfLFMKFwewLqpB/PgM=";
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
