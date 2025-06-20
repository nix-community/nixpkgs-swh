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
    outputHash = drv.outputHash;
    outputHashAlgo = drv.outputHashAlgo;
    name = drv.name;
    outputHashMode = drv.outputHashMode;
    postFetch = drv.postFetch or "";
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
