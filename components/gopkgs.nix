{ authentik-src
, authentik-version
, authentikComponents
, buildGo122Module
, lib
, makeWrapper
}:

buildGo122Module {
  pname = "authentik-gopkgs";
  version = authentik-version;
  prePatch = ''
    sed -i"" -e 's,./web/dist/,${authentikComponents.frontend}/dist/,' web/static.go
    sed -i"" -e 's,./web/dist/,${authentikComponents.frontend}/dist/,' internal/web/static.go
    sed -i"" -e 's,./lifecycle/gunicorn.conf.py,${authentikComponents.staticWorkdirDeps}/lifecycle/gunicorn.conf.py,' internal/gounicorn/gounicorn.go
  '';
  src = lib.cleanSourceWith {
    src = authentik-src;
    filter = (path: _:
      (builtins.any (x: x) (
        (map (infix: lib.hasInfix infix path) [
          "/authentik"
          "/cmd"
          "/internal"
        ])
        ++
        (map (suffix: lib.hasSuffix suffix path) [
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
  subPackages = [
    "cmd/ldap"
    "cmd/server"
    "cmd/proxy"
    "cmd/radius"
  ];
  vendorHash = "sha256-YpOG5pNw5CNSubm1OkPVpSi7l+l5UdJFido2SQLtK3g=";
  nativeBuildInputs = [ makeWrapper ];
  doCheck = false;
  postInstall = ''
    wrapProgram $out/bin/server --prefix PATH : ${authentikComponents.pythonEnv}/bin
    wrapProgram $out/bin/server --prefix PYTHONPATH : ${authentikComponents.staticWorkdirDeps}
  '';
}
