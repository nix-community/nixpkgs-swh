The CI runs the script [`./publish.sh`](./publish.sh). This script run
the script [`./generate.sh`](./generate.sh) to generate a directory
containing the `sources.json` and a README.md file containing the
analysis of this file. This directory is then commited and pushed to
the `gh-pages` branch of the current repository.

The script [`./generate.sh`](./generate.sh) can be run locally to generate the
sources.json file.
