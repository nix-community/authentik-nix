{
  authentik-src,
  authentikComponents,
  linkFarm,
  applyPatches,
}:
let
  patched-src = applyPatches {
    src = authentik-src;
    name = "patched-authentik-source";
    patches = [
      ./authentik_media_upload.patch
      ./authentik_media_tenant_files_migration.patch
    ];
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
