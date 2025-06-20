# This script processes the JSON output of the nix-instantiate call gathering
# info about nix package sources. It notably removes duplicates, normalizes
# integrity hashes and computes new fields expected by the Software Heritage
# nixguix lister. The nixguix lister source code can be browsed at this URL:
# https://gitlab.softwareheritage.org/swh/devel/swh-lister/-/tree/master/swh/lister/nixguix

import json
import subprocess
import sys

# to remove duplicates
seenStorePaths = set()

# to contain unique sources
filteredSources = []

with open(sys.argv[1], "r") as f:
    sources = json.load(f)
    for source in sources["sources"]:
        storePath = source["nixStorePath"]
        if storePath in seenStorePaths:
            # source already processed, skip it
            continue
        seenStorePaths.add(storePath)

        # extract hash algorithm and hash value
        hashArray = source["outputHash"].split(":")
        if len(hashArray) == 2:
            # nix sri format
            hashAlgo = source["outputHashAlgo"] = hashArray[0]
            hashStr = hashArray[1]
        else:
            hashAlgo = source["outputHashAlgo"]
            hashStr = source["outputHash"]
        del source["outputHash"]
        source["integrity"] = hashStr
        if (hashAlgo is None or hashAlgo == "") and hashStr.find("-") != -1:
            source["outputHashAlgo"] = hashAlgo = hashStr.split("-", 1)[0]
        if not hashAlgo:
            # assume sha256
            hashAlgo = source["outputHashAlgo"] = "sha256"

        # ensure integrity in nix sri format
        if not hashStr.endswith("=") or "-" not in hashStr:
            result = subprocess.run(
                ["nix-hash", "--to-sri", "--type", hashAlgo, hashStr],
                text=True,
                encoding="ascii",
                stdout=subprocess.PIPE,
            )
            source["integrity"] = result.stdout.rstrip()

        # add fields related to VCS souuces
        if source["type"] == "hg":
            source["hg_url"] = source["urls"][0]
            source["hg_changeset"] = source["rev"]
        elif source["type"] == "git":
            source["git_url"] = source["urls"][0]
            source["git_ref"] = source["rev"]
        elif source["type"] == "svn":
            source["svn_url"] = source["urls"][0]
            try:
                source["svn_revision"] = int(source["rev"])
            except ValueError:
                source["svn_revision"] = source["rev"]

        # remove empty/falsy fields
        del source["rev"]
        if source["type"] != "url":
            del source["urls"]
        for attr in ("submodule", "sparseCheckout", "postFetch"):
            if not source[attr]:
                del source[attr]
        filteredSources.append(source)

# dump post processed sources to file
sources["sources"] = filteredSources
with open(sys.argv[1], "w") as f:
    json.dump(sources, f)
