{ sources ? import ./sources.nix, inNixShell ? false }:

import sources.nixpkgs { inherit inNixShell; }
