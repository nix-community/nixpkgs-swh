# This script takes a sources.json as input. It generates high levels
# information (hosts, file type...) from this file and output a
# README.md.

import json
import sys
import re
from urllib.parse import urlparse

with open(sys.argv[1], "r") as read_file:
    j = json.load(read_file)

schemes = {}
hosts = {}

# To provide high level classification
origin_patterns = {
    "https?://hackage.haskell.org/.*": "hackage",
    "https?://github.com/(.*)/(.*)/archive/(.*)(?:.tar.gz|.zip)": "github_archive",  # noqa
    "https?://github.com/(.*)/(.*)/releases/download/(.*)/(.*)": "github_release",  # noqa
    "https://crates.io/api/v1/crates/(.*)/download": "crates",
    "https://bitbucket.org/(.*)/(.*)/(get|downloads)/(.*)(.tar.gz|.zip|tar.bz2)": "bitbucket",  # noqa
    "https://rubygems.org/(.*)": "rubygems",
    "svn://(.*)": "svn",
    "https://(.*)/api/v4/projects/(.*)/repository/archive.tar.gz\\?sha=(.*)": "gitlab",  # noqa
    ".*": "unknown",
}

extension_patterns = {
    ".*(.tar.gz$|.zip$|tar.bz2$|.tbz$|.tar.xz$|.tgz|.tar)": "archive",
    ".*(.gem$)": "gem",
    ".*(.pom$)": "pom",
    ".*(.jar$)": "jar",
    ".*(.deb$)": "deb",
    ".*(.patch$)": "patch",
    ".*(.diff$)": "diff",
    ".*(.rpm$)": "rpm",
    ".*(.png$)": "png",
    ".*(.msi$)": "msi",
    ".*(.iso$)": "iso",
    ".*(.c$|.h$)": "c",
    ".*(.ttf$)": "ttf",
    ".*(.rock$)": "rock",
    ".*(.whl$)": "whl",
    ".*": "unknown",
}

sources = j["sources"]
for e in sources:
    if e["type"] != "url" or not e["urls"]:
        continue
    u = urlparse(e["urls"][0])
    schemes[u.scheme] = schemes.get(u.scheme, 0) + 1
    hosts[u.netloc] = hosts.get(u.netloc, 0) + 1

    for k, v in origin_patterns.items():
        if re.search(k, e["urls"][0]) is not None:
            e["type"] = v
            break

    for k, v in extension_patterns.items():
        if re.search(k, e["urls"][0]) is not None:
            e["file-type"] = v
            break


readme = """
The file [`sources-{release}.json`](https://nix-community.github.io/nixpkgs-swh/sources-{release}.json)
has been built from the [nixpkgs revision `{revision}`](https://github.com/NixOS/nixpkgs/tree/{revision}).
This file contains `{sourceNumber}` sources, coming from`{hostNumber}` different hosts.
This file is consumed by SWH.
"""  # noqa

sortedHosts = sorted(hosts.items(), key=lambda h: h[1], reverse=True)

print(
    readme.format(
        revision=j["revision"],
        release=j["release"],
        sourceNumber=len(sources),
        hostNumber=len(sortedHosts),
    )
)


print("\n#### By host\n")
for h in sortedHosts[0:40]:
    print("     %6s %s" % (h[1], h[0]))
print("     %6s others" % sum([h[1] for h in sortedHosts[40:]]))

print("\n#### By schemes\n")
for k, v in schemes.items():
    print("     %6s %s" % (k, v))

types = {}
file_types = {}
for s in sources:
    types[s["type"]] = types.get(s["type"], 0) + 1
    if "file-type" in s:
        file_types[s["file-type"]] = file_types.get(s["file-type"], 0) + 1

print("\n#### By types\n")
for k, v in types.items():
    print("     %16s %s" % (k, v))

print("\n#### By file types\n")
for k, v in file_types.items():
    print("     %16s %s" % (k, v))
