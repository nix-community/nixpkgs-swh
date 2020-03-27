import json
import sys
import subprocess
import traceback

sources = None
with open(sys.argv[1], 'r') as f:
    sources = json.load(f)
    new = []
    for s in sources['sources']:
        try:
            result = subprocess.run(
                ['nix', 'to-sri', '--type', s['hashAlgo'], s['hash']],
                stdout=subprocess.PIPE)
            s['integrity'] = str(result.stdout.rstrip(), 'utf8')
        except TypeError as e:
            print(f'TypeError on %s' % s)
            print('-'*60)
            traceback.print_exc(file=sys.stdout)
            print('-'*60)
            
if sources is not None:
    with open(sys.argv[1], 'w') as f:
        json.dump(sources, f)
