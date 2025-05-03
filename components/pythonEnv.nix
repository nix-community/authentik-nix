{
  lib,
  callPackage,
  authentik-src,
  uv2nix,
  pythonOverlay,
  python,
  pyproject-nix,
  pyproject-build-systems,
}:

let
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = authentik-src; };
  projectOverlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          projectOverlay
          pythonOverlay
        ]
      );
in
pythonSet.mkVirtualEnv "authentik-env" (workspace.deps.default)
