{ authentik-src
, authentik-version
, authentikPoetryOverrides
, buildNapalmPackage
, defaultPoetryOverrides
, mkPoetryEnv
, pkgs
, extraPatches ? []
}:

pkgs.lib.makeScope pkgs.newScope (final:
  let
    docs = final.callPackage ./docs.nix {
      inherit authentik-version buildNapalmPackage;
    };
    frontend = final.callPackage ./frontend.nix {
      inherit authentik-version buildNapalmPackage;
    };
    pythonEnv = final.callPackage ./pythonEnv.nix {
      inherit mkPoetryEnv defaultPoetryOverrides authentikPoetryOverrides;
    };
    # server + outposts
    gopkgs = final.callPackage ./gopkgs.nix {
      inherit authentik-version;
    };
    staticWorkdirDeps = final.callPackage ./staticWorkdirDeps.nix {
      inherit extraPatches;
    };
    migrate = final.callPackage ./migrate.nix { };
    # worker
    manage = final.callPackage ./manage.nix { };
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
        manage;
    };
    inherit authentik-src authentik-version;
  }
)
