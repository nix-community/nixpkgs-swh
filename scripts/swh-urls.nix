{ revision ? null, release ? null, evaluation ? null, timestamp ? null }:

with builtins;
let
  pkgs = import <nixpkgs> { };
  mirrors = import <nixpkgs/pkgs/build-support/fetchurl/mirrors.nix>;
  expr = import <nixpkgs/maintainers/scripts/all-tarballs.nix>;
  urls = import ./find-tarballs.nix { expr = expr; };

  # This is avoid double slashes in urls that make url non valid
  concatUrls = a: b:
    (pkgs.lib.removeSuffix "/" a) + "/" + (pkgs.lib.removePrefix "/" b);

  # If the url scheme is `mirror`, this translates this mirror to a real URL by looking in nixpkgs mirrors
  resolveMirrorUrl = url:
    with pkgs.lib;
    let
      splited = splitString "/" url;
      isMirrorUrl = elemAt splited 0 != "mirror:";
      mirror = elemAt splited 2;
      path = concatStringsSep "/" (drop 3 splited);
      resolvedUrls = getAttr mirror mirrors;
    in if isMirrorUrl then [ url ] else map (r: concatUrls r path) resolvedUrls;

  # Transform the url list to swh format
  toSwh = s: {
    inherit (s) postFetch outputHashMode outputHashAlgo outputHash;
    type = "url";
    # There are expressions where the url is a list. See paratype-pt-mono
    # derivation: the url attribute is a list :/
    urls = if isList s.url then s.url else resolveMirrorUrl s.url;
  };
in {
  inherit revision release evaluation timestamp;
  version = 1;
  sources = map toSwh urls;
}
