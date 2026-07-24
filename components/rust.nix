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

  cargoHash = "sha256-bpS1cXIG8srVE4tTS1rXL6R+ZBE65BZTlMghSPiAJy4=";
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
