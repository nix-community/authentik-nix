{ authentik-src
, authentik-version
, authentikComponents
, buildGo121Module
, lib
, makeWrapper
}:

buildGo121Module {
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
  vendorHash = "sha256-8F9emmQmbe7R+xtGrjV5ht0adGasU6WAvLa8Wxr+j8M=";
  nativeBuildInputs = [ makeWrapper ];
  postInstall = ''
    wrapProgram $out/bin/server --prefix PATH : ${authentikComponents.pythonEnv}/bin
    wrapProgram $out/bin/server --prefix PYTHONPATH : ${authentikComponents.staticWorkdirDeps}
  '';
}
