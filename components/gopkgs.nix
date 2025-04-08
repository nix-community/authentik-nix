{
  authentik-src,
  authentik-version,
  authentikComponents,
  buildGo124Module,
  lib,
  makeWrapper,
}:

buildGo124Module {
  pname = "authentik-gopkgs";
  version = authentik-version;
  prePatch = ''
    sed -i"" -e 's,./web/dist/,${authentikComponents.frontend}/dist/,' web/static.go
    sed -i"" -e 's,./web/dist/,${authentikComponents.frontend}/dist/,' internal/web/static.go
    sed -i"" -e 's,./lifecycle/gunicorn.conf.py,${authentikComponents.staticWorkdirDeps}/lifecycle/gunicorn.conf.py,' internal/gounicorn/gounicorn.go
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
  ];
  subPackages = [
    "cmd/ldap"
    "cmd/server"
    "cmd/proxy"
    "cmd/radius"
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
  '';
}
