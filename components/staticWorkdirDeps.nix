{ authentik-src
, authentikComponents
, linkFarm
}:

linkFarm "authentik-static-workdir-deps" [
  { name = "authentik"; path = "${authentik-src}/authentik"; }
  { name = "locale"; path = "${authentik-src}/locale"; }
  { name = "blueprints"; path = "${authentik-src}/blueprints"; }
  { name = "internal"; path = "${authentik-src}/internal"; }
  { name = "lifecycle"; path = "${authentik-src}/lifecycle"; }
  { name = "schemas"; path = "${authentik-src}/schemas"; }
  { name = "web"; path = authentikComponents.frontend; }
]
