{
  authentik-src,
  authentik-version,
  rustPlatform,
  authentikComponents,
  cmake,
  go,
  perl,
  gcc13,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "authentik-rust";
  version = authentik-version;
  src = authentik-src;

  __structuredAttrs = true;
  strictDeps = true;

  env.RUSTFLAGS="--cfg tokio_unstable";

  cargoHash = "sha256-KExlNyT9G3R5rnt99beT2pYrWxezMLhGw+Q9T1X2kj4=";
  nativeBuildInputs = [
    authentikComponents.pythonEnv
    cmake
    go
    perl
    gcc13
  ];

  cargoBuildFlags = [
    "--package"
    "authentik"
    "--no-default-features"
    "--features"
    "core"
    "--locked"
  ];
})
