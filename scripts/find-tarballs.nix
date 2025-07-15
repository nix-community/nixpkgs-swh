# This expression returns a list of all fetchurl calls used by ‘expr’.

with import <nixpkgs> { };
with lib;

{ expr }:

let

  root = expr;

  uniqueUrls = map (x: x.file) (genericClosure {
    startSet = map (file: {
      key = file.outputHash;
      inherit file;
    }) urls;
    operator = const [ ];
  });

  urls = map (drv: {
    url = head (drv.urls or [ drv.url ]);
    outputHash = if builtins.hasAttr "outputHash" drv
    && (!lib.strings.hasSuffix "=" drv.outputHash
      || !lib.strings.hasInfix "-" drv.outputHash) then
      builtins.convertHash {
        hash = drv.outputHash;
        toHashFormat = "sri";
        hashAlgo =
          if drv.outputHashAlgo != null then
            drv.outputHashAlgo
          else
            "sha256";
      }
    else
      drv.outputHash or "";
    outputHashAlgo = drv.outputHashAlgo or "";
    name = drv.name;
    outputHashMode = drv.outputHashMode or "";
    postFetch = drv.postFetch or "";
    rev = drv.rev or "";
    submodule = builtins.hasAttr "fetchSubmodules" drv && drv.fetchSubmodules;
    sparseCheckout =
      if builtins.hasAttr "sparseCheckout" drv then drv.sparseCheckout else [ ];
    type = if builtins.hasAttr "SVN_SSH" drv then
      "svn"
    else if builtins.hasAttr "fetchSubmodules" drv then
      "git"
    else if builtins.hasAttr "subrepoClause" drv then
      "hg"
    else
      "url";
    nixStorePath = drv.out;
  }) fetchurlDependencies;

  fetchurlDependencies =
    filter (drv: drv.outputHash or "" != "" && (drv ? url || drv ? urls))
    dependencies;

  # If a dichotomy is needed on nixpkgs:/
  # subset = let
  #   start = 14379;
  #   len = 2;
  #   sub = (pkgs.lib.sublist start len dependencies);
  # in
  # builtins.trace [ start len] sub;

  dependencies = map (x: x.value) (genericClosure {
    startSet = map keyDrv (derivationsIn' root);
    operator = { key, value }: map keyDrv (immediateDependenciesOf value);
  });

  derivationsIn' = x:
    if !canEval x then
      [ ]
    else if isDerivation x then
      optional (canEval x.drvPath) x
    else if isList x then
      concatLists (map derivationsIn' x)
    else if isAttrs x then
      concatLists (mapAttrsToList (n: v: derivationsIn' v) x)
    else
      [ ];

  keyDrv = drv:
    if canEval drv.drvPath then {
      key = drv.drvPath;
      value = drv;
    } else
      { };

  immediateDependenciesOf = drv:
    concatLists (mapAttrsToList (n: v: derivationsIn v) (removeAttrs drv
      ([ "meta" "passthru" ]
        ++ optionals (drv ? passthru) (attrNames drv.passthru))));

  derivationsIn = x:
    if !canEval x then
      [ ]
    else if isDerivation x then
      optional (canEval x.drvPath) x
    else if isList x then
      concatLists (map derivationsIn x)
    else
      [ ];

  canEval = val: (builtins.tryEval val).success;

in uniqueUrls
