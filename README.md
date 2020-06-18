This repository contains scripts to generate a
[`sources.json`](https://nix-community.github.io/nixpkgs-swh/sources-unstable.json)
file ingested by [Software
Heritage](https://www.softwareheritage.org/). This file contains all
tarballs required to build
[Nixpkgs](https://github.com/NixOS/nixpkgs/). It is generated each day
by picking a Nixpkgs commit built by
[Hydra](https://hydra.nixos.org/project/nixpkgs).

A basic analysis of this file is also generated and published
[here](https://nix-community.github.io/nixpkgs-swh).
