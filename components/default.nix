{
  authentik-src,
  authentik-version,
  authentikPoetryOverrides,
  buildNapalmPackage,
  defaultPoetryOverrides,
  mkPoetryEnv,
  pkgs,
}:

pkgs.lib.makeScope pkgs.newScope (
  final:
  let
    docs = final.callPackage ./docs.nix { };
    frontend = final.callPackage ./frontend.nix { };
    pythonEnv = final.callPackage ./pythonEnv.nix { };
    # server + outposts
    gopkgs = final.callPackage ./gopkgs.nix { };
    staticWorkdirDeps = final.callPackage ./staticWorkdirDeps.nix { };
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
        manage
        ;
    };
    inherit
      authentik-src
      authentik-version
      buildNapalmPackage
      mkPoetryEnv
      defaultPoetryOverrides
      authentikPoetryOverrides
      ;
  }
)
