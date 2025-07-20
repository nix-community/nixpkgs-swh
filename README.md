This repository contains scripts to generate a
[`sources.json`](https://nix-community.github.io/nixpkgs-swh/sources-unstable.json)
file ingested by [Software
Heritage](https://www.softwareheritage.org/). This file contains the
URL of tarballs required to build
[Nixpkgs](https://github.com/NixOS/nixpkgs/). The nix-community
Buildkite CI generates it each day by picking a Nixpkgs commit built
by [Hydra](https://hydra.nixos.org/project/nixpkgs).

A basic analysis of this file is also generated and published
[here](https://nix-community.github.io/nixpkgs-swh).

# Locally generate files

To generate files for the `nixpkgs.hello` nixpkgs subset, run `nix run
.#nixpkgs-swh-generate -- --testing /tmp/swh unstable`. This is mainly
used to debugging purposes.

If you have a lot of memory and time, to generate files for the whole nixpkgs:
```
nix run .#nixpkgs-swh-generate -- /tmp/swh unstable
```
