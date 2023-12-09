{ authentik-src
, authentik-version
, buildNapalmPackage
, nodejs_20
}:

buildNapalmPackage "${authentik-src}/website" {
  version = authentik-version; # 0.0.0 specified upstream in package.json
  NODE_ENV = "production";
  nodejs = nodejs_20;
  npmCommands = [
    "cp -v ${authentik-src}/SECURITY.md ../SECURITY.md"
    "cp -vr ${authentik-src}/blueprints ../blueprints"
    "npm install --include=dev"
    "npm run build-docs-only"
  ];
  installPhase = ''
    rm -r ../website/node_modules/.cache
    mv -v ../website $out
  '';
}
