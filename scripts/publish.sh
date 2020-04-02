#!/usr/bin/env nix-shell
#!nix-shell -i bash
#!nix-shell -I nixpkgs=./nix
#!nix-shell -p nix git openssh python3
set -euo pipefail

# TODO: get certs from nixpkgs.cacert instead or propagate some
# environment variable from the agent environment to the pipeline
# context?
export GIT_SSL_CAINFO=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt



# Clean up the previous build dir :/
rm -rf nixpkgs-swh-gh-pages
rm -rf build

./scripts/generate.sh build/ unstable # 19.09 20.03


mkdir nixpkgs-swh-gh-pages
cp build/README.md nixpkgs-swh-gh-pages/
cp build/sources*.json nixpkgs-swh-gh-pages/

cd nixpkgs-swh-gh-pages/
ls -l
echo "** Create and push the gh-pages branch"
git init
git config user.name "buildkite"
git config user.email "buildkite@none"
git add *
git commit -m 'Deploy to GitHub Pages'
export GIT_SSH_COMMAND='ssh -i /run/keys/github-nixpkgs-swh-key'
export REMOTE_REPO="git@github.com:nix-community/nixpkgs-swh.git"
git push --force $REMOTE_REPO master:gh-pages
