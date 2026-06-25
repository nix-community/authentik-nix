{
  authentik-src,
  authentik-version,
  stdenv,
  nodejs_26,
  typescript,
  writableTmpDirAsHomeHook,
}:

stdenv.mkDerivation {
  pname = "authentik-client-ts";
  version = authentik-version; # 0.0.0 specified upstream in package.json

  src = "${authentik-src}/packages/client-ts";

  nativeBuildInputs = [
    nodejs_26
    typescript
    writableTmpDirAsHomeHook
  ];

  buildPhase = ''
    npm run build
  '';

  installPhase = ''
    mkdir $out
    cp -rv dist package.json $out/
  '';
}
