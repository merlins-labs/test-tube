#!/usr/bin/env bash

set -euxo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ROOT_DIR="$SCRIPT_DIR/.."


# get latest merlin tag timestamp from workflow state
LATEST_MERLIN_TAG_TIMESTAMP_PATH="$SCRIPT_DIR/../workflow-state/LATEST_MERLIN_TAG_TIMESTAMP"
LATEST_MERLIN_TAG_TIMESTAMP=$(cat "$LATEST_MERLIN_TAG_TIMESTAMP_PATH" || echo 0)


git submodule update --init --recursive 
cd packages/merlin-test-tube/merlin

# list all branches/tags with:
# `<branch_name> <commit_hash>`
FORMAT="%(refname:short) %(committerdate:unix)"

# get all related revisions
REVS="$(git branch -r --format="$FORMAT" --list origin/main && \
    git branch -r --format="$FORMAT" --list origin/v* && \
    git tag --format="$FORMAT" --list v*)"

# filter only rev that's greater than latest tag
MATRIX=$(
    echo "$REVS" | \
    awk -v latest_tag_timestamp="$LATEST_MERLIN_TAG_TIMESTAMP" '$2 >= latest_tag_timestamp { print $1 }' | \

    # jq filter target revs only v14 and above or main
    jq -RMrnc '{ "target": [inputs | select( test("^origin/main$") or ((capture("v(?<v>[0-9]+)") | .v | tonumber) >= 14))] }'
)

# update latest tag timestmap
rm -f "$LATEST_MERLIN_TAG_TIMESTAMP_PATH"
LATEST_MERLIN_TAG_TIMESTAMP="$(git tag --format="$FORMAT" | awk '{ print $2 }' | sort -nr | head -n 1)"

echo "$LATEST_MERLIN_TAG_TIMESTAMP" > "$LATEST_MERLIN_TAG_TIMESTAMP_PATH"

cd "$ROOT_DIR"

# if dirty or untracked file exists
if [[ $(git diff --stat) != '' ||  $(git ls-files  --exclude-standard  --others) ]]; then
    git add "$LATEST_MERLIN_TAG_TIMESTAMP_PATH"
    git commit -m "Update latest merlin tag timestamp to $LATEST_MERLIN_TAG_TIMESTAMP"
    git push
fi

# pass along target rev matrix
echo "matrix=$MATRIX" >> $GITHUB_OUTPUT