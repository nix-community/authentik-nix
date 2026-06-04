{
  authentik-src,
  authentik-version,
  authentikComponents,
  buildGo126Module,
  lib,
  makeWrapper,
  guacamole-server,
  stdenv,
  patches,
  generatedGoClient,
}:

let
  guacamoleAvailable = lib.meta.availableOn stdenv.hostPlatform guacamole-server;

in
buildGo126Module {
  pname = "authentik-gopkgs";
  version = authentik-version;
  inherit patches;
  prePatch = ''
    sed -i"" -e 's,./web/dist/,${authentikComponents.frontend}/dist/,' web/static.go
    sed -i"" -e 's,./web/dist/,${authentikComponents.frontend}/dist/,' internal/web/static.go
    sed -i"" -e 's,./lifecycle/gunicorn.conf.py,${authentikComponents.staticWorkdirDeps}/lifecycle/gunicorn.conf.py,' internal/gounicorn/gounicorn.go
    mkdir packages
    cp --no-preserve=mode -vr ${generatedGoClient} packages/client-go
  '' + lib.optionalString guacamoleAvailable ''
    substituteInPlace internal/outpost/rac/guacd.go \
      --replace-fail '/opt/guacamole/sbin/guacd' \
                     "${lib.getExe guacamole-server}"
  '';
  src = lib.cleanSourceWith {
    src = authentik-src;
    filter = (
      path: _:
      (builtins.any (x: x) (
        (map (infix: lib.hasInfix infix path) [
          "/authentik"
          "/cmd"
          "/internal"
        ])
        ++ (map (suffix: lib.hasSuffix suffix path) [
          "/web"
          "/web/static.go"
          "/web/robots.txt"
          "/web/security.txt"
          "go.mod"
          "go.sum"
          "schema.yml"
        ])
      ))
    );
  };
  outputs = [
    "out"
    "ldap"
    "proxy"
    "radius"
  ] ++ lib.optionals guacamoleAvailable [
    "rac"
  ];
  subPackages = [
    "cmd/ldap"
    "cmd/server"
    "cmd/proxy"
    "cmd/radius"
  ] ++ lib.optionals guacamoleAvailable [
    "cmd/rac"
  ];
  vendorHash = "sha256-EVDOZ4USaJoIBDB8mM4ZSBfsSc1d/NOm1Qv/hUJ+8f4=";
  nativeBuildInputs = [ makeWrapper ];
  doCheck = false;
  postInstall = ''
    wrapProgram $out/bin/server --prefix PATH : ${authentikComponents.pythonEnv}/bin
    wrapProgram $out/bin/server --prefix PYTHONPATH : ${authentikComponents.staticWorkdirDeps}

    mkdir -p $ldap/bin $proxy/bin $radius/bin
    mv $out/bin/ldap $ldap/bin/
    mv $out/bin/proxy $proxy/bin/
    mv $out/bin/radius $radius/bin/
  '' + lib.optionalString guacamoleAvailable ''
    mkdir -p $rac/bin
    mv $out/bin/rac $rac/bin/
  '';
}
