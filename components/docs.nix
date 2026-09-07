{
  authentik-src,
  authentik-version,
  stdenvNoCC,
  pnpm_11,
  pnpmConfigHook,
  fetchPnpmDeps,
  nodejs_26,
}:

let
  nodejs = nodejs_26;
  pnpm = pnpm_11.override { nodejs-slim = nodejs; };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "authentik-docs";
  version = authentik-version; # 0.0.0 specified upstream in package.json

  src = "${authentik-src}/website";

  env.NODE_ENV = "production";

  nativeBuildInputs = [
    nodejs_26
    pnpmConfigHook
    pnpm
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-TV9f+BezxYHkXjhQiLl1WC3i0q8+oCfzd2fy3fktc0M=";
  };

  postPatch = ''
    cp -v ${authentik-src}/SECURITY.md ../SECURITY.md
    cp -vr ${authentik-src}/blueprints ../blueprints
    cp -v ${authentik-src}/schema.yml ../schema.yml
    mkdir -p ../lifecycle/container
    cp -v ${authentik-src}/lifecycle/container/compose.yml ../lifecycle/container/compose.yml
  '';

  installPhase = ''
    runHook preInstall

    rm -f ../website/static/blueprints
    cp -vr ../blueprints ../website/static/blueprints
    cp -vr ../website $out
    # remove broken symlinks we'd get a build failure for. Do this explicitly
    # to avoid having other broken symlinks, these are not relevant for
    # production deployments anyways.
    rm $out/node_modules/@goauthentik/{prettier-config,tsconfig,eslint-config}
    rm $out/integrations/node_modules/@goauthentik/docusaurus-config
    rm $out/docs/node_modules/@goauthentik/docusaurus-config
    rm $out/docusaurus-theme/node_modules/@goauthentik/docusaurus-config
    rm $out/api/node_modules/@goauthentik/docusaurus-config

    runHook postInstall
  '';
})
