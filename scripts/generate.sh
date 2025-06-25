#!/usr/bin/env nix-shell
#!nix-shell -i bash
#!nix-shell -p nix git openssh python3 python3Packages.aiohttp python3Packages.uvloop curl jq
set -euo pipefail


generate-release() {
    echo "** Generate sources.json and README for release $1"
    RELEASE=$1

    if [[ $1 == "unstable" ]]
    then
        HYDRA_JOBNAME="trunk-combined"
    else
        HYDRA_JOBNAME="release-${1}"
    fi

    echo "*** Query Hydra to get latest build commit"
    HYDRA=$(curl -s -L -H "Accept: application/json" \
                 https://hydra.nixos.org/jobset/nixos/${HYDRA_JOBNAME}/latest-eval \
                 | jq -r '"\(.id) \(.jobsetevalinputs.nixpkgs.revision)"')

    EVAL_ID=$(echo $HYDRA | cut -d" " -f1)
    COMMIT_ID=$(echo $HYDRA | cut -d" " -f2)

    # If the Hydra call fails, it returns (null, null)
    if [ $EVAL_ID == "null" ] || [ $COMMIT_ID == "null" ];
    then
        echo "error: the release $RELEASE has not been found on Hydra"
        exit 1
    fi

    export SOURCES_FILE=${DEST_DIR}/sources-${RELEASE}.json

    echo "*** Generate sources-${RELEASE}.json for commit $COMMIT_ID ..."
    # This is to make nix-instantiate failing if the commit id can not be downloaded
    unset NIX_PATH
    export GC_INITIAL_HEAP_SIZE=4g
    # TODO: get the timestamp of the evaluation with the Hydra API. I
    # don't think it is currently possible so I would have to extend
    # its API first.
    time nix-instantiate \
        -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/${COMMIT_ID}.tar.gz \
        --strict --eval --json \
        ./scripts/swh-urls.nix \
        --argstr revision $COMMIT_ID \
        --argstr release ${RELEASE} \
        --argstr evaluation ${EVAL_ID} \
        --argstr timestamp $(date +%s) \
        --show-trace \
        > ${SOURCES_FILE}

    echo "*** Post process extracted sources data"
    time python ./scripts/post-process.py ${SOURCES_FILE}

    echo "*** Analyze the sources.json file and generating the README in sources-${RELEASE}.md ..."
    time python ./scripts/analyze.py ${SOURCES_FILE} > ${DEST_DIR}/readme-${RELEASE}.md
}


generate-readme() {
    cat <<EOF > ${DEST_DIR}/README.md
Fill the Software Heritage archive

EOF

for i in $@; do
    generate-release ${i}
    echo "### NixOS \`${i}\`" >> ${DEST_DIR}/README.md
    cat ${DEST_DIR}/readme-${i}.md >> ${DEST_DIR}/README.md
    echo >> ${DEST_DIR}/README.md
    echo >> ${DEST_DIR}/README.md
    shift
done
}


DEST_DIR=$1
mkdir -p ${DEST_DIR}
shift

generate-readme $@
