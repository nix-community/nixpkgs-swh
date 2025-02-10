{
  description = "nixpkgs-swh";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [ self.overlay ];
    };
  in {
    overlay = final: prev: {
      nixpkgs-swh-generate = let
        binPath = with final; lib.makeBinPath [ curl nix python3 jq pandoc ];
      in final.stdenv.mkDerivation {
        name = "nixpkgs-swh-generate";
        dontUnpack = true;
        nativeBuildInputs = [ final.makeWrapper ];
        installPhase = ''
          mkdir -p $out/bin
          cp ${./scripts/generate.sh} $out/bin/nixpkgs-swh-generate
          substituteInPlace $out/bin/nixpkgs-swh-generate \
            --replace-fail './scripts/swh-urls.nix' '${./scripts/swh-urls.nix}' \
            --replace-fail './scripts/add-sri.py' '${./scripts/add-sri.py}' \
            --replace-fail './scripts/analyze.py' '${./scripts/analyze.py}' \
            --replace-fail '$PWD/scripts/find-tarballs.nix' '${./scripts/find-tarballs.nix}'
          wrapProgram $out/bin/nixpkgs-swh-generate \
            --prefix PATH : ${binPath}
        '';
      };
    };

    packages.x86_64-linux.nixpkgs-swh-generate = pkgs.nixpkgs-swh-generate;
    defaultPackage.x86_64-linux = pkgs.nixpkgs-swh-generate;

    nixosModules.nixpkgs-swh = { config, pkgs, lib, ... }: let
      cfg = config.services.nixpkgs-swh;
      dir = "/var/lib/nixpkgs-swh";
    in {
      options = {
        services.nixpkgs-swh = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether to run the nixpkgs-swh service.
            '';
          };
          testing = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Whether to only evaluate the hello attribute for testing purpose.
            '';
          };
          fqdn = lib.mkOption {
            type = lib.types.str;
            description = ''
              The Nginx vhost FQDN used to serve built files.
            '';
          };
        };
      };
      config = lib.mkIf cfg.enable {
        nixpkgs.overlays = [ self.overlay ];
        systemd.services.nixpkgs-swh = {
          description = "nixpkgs-swh";
          wantedBy = [ "multi-user.target" ];
          # Do it every day
          startAt = "daily";
          script = ''
            ${pkgs.nixpkgs-swh-generate}/bin/nixpkgs-swh-generate ${dir} ${if cfg.testing then "true" else "false"} unstable
          '';
        };
        systemd.timers.nixpkgs-swh.timerConfig = {
          Persistent = true;
        };
        services.nginx.virtualHosts = {
          "${cfg.fqdn}" = {
            locations."/" = {
              root = "${dir}";
              extraConfig = ''
                autoindex on;
              '';
            };
          };
        };
      };
    };
  };
}
