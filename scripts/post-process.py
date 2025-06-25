# This script processes the JSON output of the nix-instantiate call gathering
# info about nix package sources. It notably removes duplicates, normalizes
# integrity hashes and computes new fields expected by the Software Heritage
# nixguix lister. The nixguix lister source code can be browsed at this URL:
# https://gitlab.softwareheritage.org/swh/devel/swh-lister/-/tree/master/swh/lister/nixguix

import asyncio
import json
import sys

import aiohttp
import uvloop

# to remove duplicates
seenStorePaths = set()

# to contain unique sources
filteredSources = []
# nix-hash commands to execute asynchronously
hashesToNormalize = []

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
            hashesToNormalize.append(
                (f"nix-hash --to-sri --type {hashAlgo} {hashStr}", source)
            )

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


async def normalize_hash(nixhash_cmd, source, sem):
    await sem.acquire()
    try:
        print(f"Executing '{nixhash_cmd}'")
        proc = await asyncio.create_subprocess_shell(
            nixhash_cmd,
            stderr=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
        )
        stdout, _ = await proc.communicate()
        source["integrity"] = stdout.decode().strip()
    finally:
        sem.release()


async def normalize_hashes(hashesToNormalize):
    sem = asyncio.Semaphore(100)
    await asyncio.gather(
        *(normalize_hash(cmd, source, sem) for cmd, source in hashesToNormalize)
    )


async def narinfo_get(source, session):
    try:
        hash_store = source["nixStorePath"].split("/")[-1].split("-", 1)[0]
        url = f"https://cache.nixos.org/{hash_store}.narinfo"
        async with session.get(url) as response:
            narinfo = await response.read()
            print(f"Successfully got URL {url} with resp of length {len(narinfo)}.")
            source["narinfo"] = narinfo.decode()
            if source["narinfo"] != "404":
                source["last_modified"] = response.headers["last-modified"]
    except Exception as e:
        print(f"Unable to get URL {url} due to {str(e)}.")


async def fetch_narinfos(filteredSources):
    async with aiohttp.ClientSession() as session:
        await asyncio.gather(
            *(narinfo_get(source, session) for source in filteredSources)
        )

# normalize hashes that need it using nix-hash tool
uvloop.run(normalize_hashes(hashesToNormalize))

# fetch narinfo data from the nix remote cache
uvloop.run(fetch_narinfos(filteredSources))

# dump post processed sources to file
sources["sources"] = filteredSources
with open(sys.argv[1], "w") as f:
    json.dump(sources, f)
