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

  cargoHash = "sha256-+vw/7bEWNc+uSTHKyzXrO9yJCK0JCrRSGJ4t5YufgIA=";
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
