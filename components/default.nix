{ authentik-src
, authentik-version
, authentikPoetryOverrides
, buildNapalmPackage
, defaultPoetryOverrides
, mkPoetryEnv
, pkgs
}:

pkgs.lib.makeScope pkgs.newScope (final:
  let
    docs = final.callPackage ./docs.nix {
      inherit authentik-src authentik-version buildNapalmPackage;
    };
    frontend = final.callPackage ./frontend.nix {
      inherit authentik-src authentik-version buildNapalmPackage;
    };
    pythonEnv = final.callPackage ./pythonEnv.nix {
      inherit authentik-src mkPoetryEnv defaultPoetryOverrides authentikPoetryOverrides;
    };
    # server + outposts
    gopkgs = final.callPackage ./gopkgs.nix {
      inherit authentik-src authentik-version;
    };
    staticWorkdirDeps = final.callPackage ./staticWorkdirDeps.nix {
      inherit authentik-src;
    };
    migrate = final.callPackage ./migrate.nix {
      inherit authentik-src;
    };
    # worker
    celery = final.callPackage ./celery.nix {
    };
  in
  {
    authentikComponents = {
      inherit
        docs
        frontend
        pythonEnv
        gopkgs
        staticWorkdirDeps
        migrate
        celery;
    };
    inherit authentik-src authentik-version;
  }
)
