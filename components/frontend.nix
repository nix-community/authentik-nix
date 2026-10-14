{
  authentik-src,
  authentik-version,
  authentikComponents,
  stdenvNoCC,
  pnpm_12,
  pnpmConfigHook,
  fetchPnpmDeps,
  nodejs_26,
}:

let
  nodejs = nodejs_26;
  pnpm = pnpm_12.override { nodejs-slim = nodejs; };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "authentik-web";
  version = authentik-version; # 0.0.0 specified upstream in package.json

  src = "${authentik-src}/web";

  nativeBuildInputs = [
    nodejs_26
    pnpmConfigHook
    pnpm
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-KgS6uCZGe/9QUkTtvUgk8ZXnaAcCYxQMb8pumluA9kY=";
  };

  postPatch = ''
    rm packages/client-ts
    cp -rv --no-preserve=mode ${authentikComponents.client-ts} packages/client-ts
  '';

  preBuild = ''
    cp -rv --no-preserve=mode ${authentik-src}/packages ../
    ln -sv ${authentik-src}/website ../website
    ln -sv ${authentik-src}/package.json ../
  '';

  buildPhase = ''
    runHook preBuild

    npm run build
    npm run build:sfe

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir $out
    mv dist $out/dist
    cp -r authentik $out

    find $out/dist/ -name "*.map" -delete

    runHook postInstall
  '';
})
