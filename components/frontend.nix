{ authentik-src
, authentik-version
, authentikComponents
, buildNapalmPackage
, nodejs_22
, applyPatches
}:
let
  patched-src = applyPatches {
    src = authentik-src;
    name = "patched-authentik-source";
    patches = [
      # Should be obsolete with the next release (i.e. 2024.4.2).
      #
      # The underlying issue was partially fixed by backporting https://github.com/goauthentik/authentik/pull/9419
      # to 2024.4, but two deps are still missing the resolved/integrity fields in 2024.4.1
      #
      # (this introduces IFD)
      ./frontend-package-lock-json-missing-integrity-infos.patch
    ];
  };
in
buildNapalmPackage "${patched-src}/web" rec {
  version = authentik-version; # 0.0.0 specified upstream in package.json
  NODE_ENV = "production";
  nodejs = nodejs_22;
  preBuild = ''
    ln -sv ${authentikComponents.docs} ../website
  '';
  npmCommands = [
    "npm install --include=dev --nodedir=${nodejs}/include/node --loglevel verbose --ignore-scripts"
    "npm run build"
  ];
  installPhase = ''
    mkdir $out
    mv dist $out/dist
    cp -r authentik icons $out
  '';
}
