# authentik-nix

A Nix flake providing a package, NixOS module and basic VM test for [authentik](https://github.com/goauthentik/authentik)

## TOC
- [Important Note](#important-note)
- [Overview](#overview)
- [Usage](#usage)
- [Updating](#updating)
- [License](#license)

## Important Note
Please note that this project is not directly affiliated with the official [authentik](https://github.com/goauthentik/authentik) project. Most importantly this means that there is no official support for this packaging and deployment approach. Therefore, please refrain from opening issues for the official project when running into problems with this flake. Feel free to open issues here. If in doubt, please open an issue here first so we can make sure that it's not directly related to this packaging/deployment approach before escalating to the official project.

## Overview

* [flake.nix](./flake.nix)
  This flake provides packages (server, worker, outposts, ...) as outputs, a NixOS module and a simple VM integration test for the module.
* [module.nix](./module.nix)
  The NixOS module configures authentik services, redis and (by default) a local postgres instance. The upstream default authentik configuration can be partially overridden by setting desired parameters under `services.authentik.settings`.
* [poetry2nix-python-overrides.nix](./poetry2nix-python-overrides.nix)
  contains overrides and fixes for building the python env
* [test.nix](./test.nix)
  A minimal NixOS VM test. Confirms that the services configured by the module start and manually goes through the initial setup flow. Two screenshots are taken during test execution to confirm that the frontend is rendered correctly.

## Usage

* WiP

## Updating

* WiP

## License
This project is released under the terms of the MIT License. See [LICENSE](./LICENSE).
Consult [the upstream project](https://github.com/goauthentik/authentik) for information about authentik licensing.
