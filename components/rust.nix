{
  lib,
  authentik-src,
  authentik-version,
  rustPlatform,
  authentikComponents,
  cmake,
  pkg-config,
  go,
  perl,
  clangStdenv,
  cacert,
  python,
  zstd,
}:

# this adds a clang to the build environment, but it does not changes the compiler
# cargo hands over to build scripts o crates: see AWS_LC_FIPS_SYS_HOST_CC
(rustPlatform.buildRustPackage.override { stdenv = clangStdenv; }) {
  pname = "authentik-rust";
  version = authentik-version;
  src = authentik-src;

  __structuredAttrs = true;
  strictDeps = true;

  env = {
    RUSTFLAGS = "--cfg tokio_unstable";
    PYO3_PYTHON = lib.getExe python;

    # stop go from downloading itself, and use the nixpkgs compiler and toolchain.
    GOTOOLCHAIN = "local";

    ZSTD_SYS_USE_PKG_CONFIG = "1";

    # aws-lc-fips-sys has its own env var to ignore the compiler provided by cargo
    AWS_LC_FIPS_SYS_HOST_CC = "${clangStdenv.cc}/bin/${clangStdenv.cc.targetPrefix}cc";
  };

  cargoHash = "sha256-q445NakFvkgBZ/UwmHxYVDlOzaqR3yKbuJfIRpMZhdw=";
  nativeBuildInputs = [
    pkg-config
    # for aws-lc-fips-sys
    cmake
    go
    perl
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
