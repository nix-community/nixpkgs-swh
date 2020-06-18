import json
import sys
import subprocess
import traceback

# These are heuristics to detect the fetcher, based on the postFetch value!
fetchZipPattern = "Pass stripRoot=false; to fetchzip to assume flat list of files"
fetchpatchPattern = "Did you maybe fetch a HTML representation of a patch instead of a raw patch"

sources = None
with open(sys.argv[1], 'r') as f:
    sources = json.load(f)
    new = []
    for s in sources['sources']:
        try:
            hashArray = s['outputHash'].split(":")
            if len(hashArray) == 2:
                hashAlgo = hashArray[0]
                hashStr = hashArray[1]
            else:
                hashAlgo = s['outputHashAlgo']
                hashStr = s['outputHash']

            result = subprocess.run(
                ['nix', 'to-sri', '--type', hashAlgo, hashStr],
                stdout=subprocess.PIPE)
            s['integrity'] = str(result.stdout.rstrip(), 'utf8')
        except TypeError as e:
            print(f'TypeError on %s' % s)
            print('-'*60)
            traceback.print_exc(file=sys.stdout)
            print('-'*60)

        # We try to infer the fetcher
        s['inferredFetcher'] = 'unclassified'
        if fetchZipPattern in s['postFetch']:
            s['inferredFetcher'] = 'fetchzip'
        elif fetchpatchPattern in s['postFetch']:
            s['inferredFetcher'] = 'fetchpatch'
        del s['postFetch']
            
if sources is not None:
    with open(sys.argv[1], 'w') as f:
        json.dump(sources, f)
