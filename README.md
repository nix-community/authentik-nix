# authentik-nix

A Nix flake providing a package, NixOS module and basic VM test for [authentik](https://github.com/goauthentik/authentik)

## Important Note
Please note that this project is not directly affiliated with the official [authentik](https://github.com/goauthentik/authentik) project. Most importantly this means that there is no official support for this packaging and deployment approach. Therefore, please refrain from opening issues for the official project when running into problems with this flake. Feel free to open issues here. If in doubt, please open an issue here first so we can make sure that it's not directly related to this packaging/deployment approach before escalating to the official project.

## Overview

* [flake.nix](./flake.nix)
  This flake provides packages (server, worker, outposts, ...) as outputs, a NixOS module and a simple VM integration test for the module.
* [module.nix](./module.nix)
  The NixOS module configures authentik services, redis and (by default) a local postgres instance. The upstream default authentik configuration can be partially overridden by setting desired parameters under `services.authentik.settings`.
* [poetry2nix-python-overrides.nix](./poetry2nix-python-overrides.nix)
  contains overrides and fixes for building the python env
* [minimal-vmtest.nix](./tests/minimal-vmtest.nix)
  A minimal NixOS VM test. Confirms that the services configured by the module start and manually goes through the initial setup flow. Some screenshots are taken during test execution to confirm that the frontend is rendered correctly.
* [components](./components/default.nix)
  An overridable scope, including the individual authentik components. An example for how to create a custom scope is provided in [override-scope.nix](./tests/override-scope.nix).

## Usage

Example configuration:

```nix
{
  services.authentik = {
    enable = true;
    # The environmentFile needs to be on the target host!
    # Best use something like sops-nix or agenix to manage it
    environmentFile = "/run/secrets/authentik/authentik-env";
    settings = {
      email = {
        host = "smtp.example.com";
        port = 587;
        username = "authentik@example.com";
        use_tls = true;
        use_ssl = false;
        from = "authentik@example.com";
      };
      disable_startup_analytics = true;
      avatars = "initials";
    };
  };
}
```

**EnvironmentFile for secrets**

The `environmentFile` option references a systemd [EnvironmentFile](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#EnvironmentFile=), that needs to be placed on the same host as authentik and should only be accessible to root. Secrets can be specified in this environment file without causing them to be placed in the world-readable /nix/store. Note that `pkgs.writeText` and similar tooling also causes secrets to be placed in the /nix/store.

After generating a secret key for authentik, for example using `openssl rand -base64 32` the file's contents should look like this:

```
AUTHENTIK_SECRET_KEY=<generated secret key>
AUTHENTIK_EMAIL__PASSWORD=<smtp password>
```

Better alternatives to managing the environment file manually on the authentik host might be https://github.com/Mic92/sops-nix or https://github.com/ryantm/agenix , depending on your use case.

### With flakes

Add authentik-nix to your flake, import the module and configure it. Relevant sections of the flake:

```nix
# flake.nix
{
  inputs.authentik-nix = {
    url = "github:nix-community/authentik-nix";

    ## optional overrides. Note that using a different version of nixpkgs can cause issues, especially with python dependencies
    # inputs.nixpkgs.follows = "nixpkgs"
    # inputs.flake-parts.follows = "flake-parts"
  };

  outputs = inputs@{ ... }: {

    ## regular NixOS example
    #
    # nixosConfigurations = {
    #   authentik-host = inputs.nixpkgs.lib.nixosSystem {
    #     system = "x86_64-linux";
    #     modules = [
    #       inputs.authentik-nix.nixosModules.default
    #       {
    #         services.authentik = {
    #           # ... further configuration; see example configuration above
    #         };
    #       }
    #     ];
    #   };
    # };

    ## Colmena example
    #
    # colmena = {
    #   meta.specialArgs.inputs = { inherit (inputs) authentik-nix; };
    #
    #   authentik-host = { inputs, ... }: {
    #     imports = [ inputs.authentik-nix.nixosModules.default ];
    #
    #     services.authentik = {
    #       # ... further configuration; see example configuration above
    #     };
    #   };
    # };
  };
}
```

## Without flakes

All packages, modules and tests are available via flake-compat and may be used without flakes.
This requires some extra work, but this example NixOS configuration may help you to get started:

```nix
# configuration.nix
{ ... }:
let
  authentik-version = "2024.2.3";
  authentik-nix-src = builtins.fetchTarball {
    url = "https://github.com/nix-community/authentik-nix/archive/version/${authentik-version}.tar.gz";
    sha256 = "15b9a2csd2m3vwhj3xc24nrqnj1hal60jrd69splln0ynbnd9ki4";
  };
  authentik-nix = import authentik-nix-src;
in
{
  imports = [
    authentik-nix.nixosModules.default
  ];

  services.authentik = {
    # ...
  };

  system.stateVersion = "23.11";
}
```

## Nginx + Let's Encrypt

Example configuration:

```nix
{
  services.authentik = {
    # other authentik options as in the example configuration at the top
    nginx = {
      enable = true;
      enableACME = true;
      host = "auth.example.com";
    };
  };
}
```

The configuration above configures authentik to auto-discover the Let's Encrypt certificate and key.
Initial auto-discovery might take a while because the authentik certificate discovery task runs once per hour.

## Testing

To run the tests execute the following:

```
nix flake check --print-build-logs
```

## License
This project is released under the terms of the MIT License. See [LICENSE](./LICENSE).
Consult [the upstream project](https://github.com/goauthentik/authentik) for information about authentik licensing.
