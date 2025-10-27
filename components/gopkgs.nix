{
  authentik-src,
  authentik-version,
  authentikComponents,
  buildGo124Module,
  lib,
  makeWrapper,
  guacamole-server,
  stdenv,
}:

let
  guacamoleAvailable = lib.meta.availableOn stdenv.hostPlatform guacamole-server;
in
buildGo124Module {
  pname = "authentik-gopkgs";
  version = authentik-version;
  prePatch = ''
    sed -i"" -e 's,./web/dist/,${authentikComponents.frontend}/dist/,' web/static.go
    sed -i"" -e 's,./web/dist/,${authentikComponents.frontend}/dist/,' internal/web/static.go
    sed -i"" -e 's,./lifecycle/gunicorn.conf.py,${authentikComponents.staticWorkdirDeps}/lifecycle/gunicorn.conf.py,' internal/gounicorn/gounicorn.go
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
  vendorHash = "sha256-wTTEDBRYCW1UFaeX49ufLT0c17sacJzcCaW/8cPNYR4=";
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
