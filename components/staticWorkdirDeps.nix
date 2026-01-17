{
  authentik-src,
  authentikComponents,
  linkFarm,
  applyPatches,
  patches,
}:
let
  patched-src = applyPatches {
    src = authentik-src;
    name = "patched-authentik-source";
    inherit patches;
  };
in
linkFarm "authentik-static-workdir-deps" [
  {
    name = "authentik";
    path = "${patched-src}/authentik";
  }
  {
    name = "locale";
    path = "${authentik-src}/locale";
  }
  {
    name = "blueprints";
    path = "${authentik-src}/blueprints";
  }
  {
    name = "internal";
    path = "${authentik-src}/internal";
  }
  {
    name = "lifecycle";
    path = "${patched-src}/lifecycle";
  }
  {
    name = "schemas";
    path = "${authentik-src}/schemas";
  }
  {
    name = "web";
    path = authentikComponents.frontend;
  }
]
