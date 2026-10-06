{
  lib,
  authentik-src,
  authentik-version,
  rustPlatform,
  authentikComponents,
  pkg-config,
  cacert,
  python,
  zstd,
}:

# this adds a clang to the build environment, but it does not changes the compiler
# cargo hands over to build scripts o crates: see AWS_LC_FIPS_SYS_HOST_CC
rustPlatform.buildRustPackage {
  pname = "authentik-rust";
  version = authentik-version;
  src = authentik-src;

  __structuredAttrs = true;
  strictDeps = true;

  env = {
    RUSTFLAGS = "--cfg tokio_unstable";
    PYO3_PYTHON = lib.getExe python;

    ZSTD_SYS_USE_PKG_CONFIG = "1";
  };

  cargoPatches = [
    ./drop_rust_fips.patch
  ];

  cargoHash = "sha256-7Y2/vqv9d66Ci8lEtu1EglG0k9uMLiLXBZBA0EyJzRE=";
  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    python
    zstd
  ];

  cargoBuildFlags = [
    "--package"
    "authentik"
    "--no-default-features"
    "--features"
    "core"
    "--locked"
  ];

  nativeCheckInputs = [
    cacert
  ];

  checkFlags = [
    # requires db with migrations applied
    "--skip=outpost::proxy::session::postgres::tests::save_load_expire_logout"
  ];

  preBuild = ''
    ln -s ${authentikComponents.frontend}/dist web/dist
  '';
}
