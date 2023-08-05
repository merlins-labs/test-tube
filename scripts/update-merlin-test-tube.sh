#!/usr/bin/env bash

set -euxo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
MERLIN_REV=${1:-main}

LATEST_MERLIN_VERSION="v16"

# if "$OSMOIS_REV" is /v\d+/ then extract it as var
if [[ "$MERLIN_REV" =~ ^v[0-9]+ ]]; then
  MERLIN_VERSION=$(echo "$MERLIN_REV" | sed "s/\..*$//")
else
  MERLIN_VERSION="$LATEST_MERLIN_VERSION"
fi

########################################
## Update and rebuild merlin-test-tube ##
########################################

# update all submodules
git submodule update --init --recursive


# build and run update-merlin-test-tube
cd "$SCRIPT_DIR/update-merlin-test-tube-deps" && go build

MERLIN_REV_NO_ORIGIN="$(echo "$MERLIN_REV" | sed "s/^origin\///")"

# run update-merlin-test-tube-deps which will replace the `replace directives` in merlin-test-tube
# with merlin' replaces
"$SCRIPT_DIR/update-merlin-test-tube-deps/update-merlin-test-tube-deps" "$MERLIN_REV_NO_ORIGIN"

cd "$SCRIPT_DIR/../packages/merlin-test-tube/merlin"
PARSED_REV=$(git rev-parse --short "$MERLIN_REV")

cd "$SCRIPT_DIR/../packages/merlin-test-tube/libmerlintesttube"

go get "github.com/merlins-labs/merlin/v16@${PARSED_REV}"

# tidy up updated go.mod
go mod tidy


########################################
## Update git revision if there is    ##
## any change                         ##
########################################

# if dirty or untracked file exists
if [[ $(git diff --stat) != '' ||  $(git ls-files  --exclude-standard  --others) ]]; then
  # add, commit and push
  git add "$SCRIPT_DIR/.."
  git commit -m "rebuild with $(git rev-parse --short HEAD:dependencies/merlin)"

  # remove "origin/"
  MERLIN_REV=$(echo "$MERLIN_REV" | sed "s/^origin\///")
  BRANCH="autobuild-$MERLIN_REV"

  # force delete local "$BRANCH" if exists
  git branch -D "$BRANCH" || true

  git checkout -b "$BRANCH"
  git push -uf origin "$BRANCH"
else
  echo '[CLEAN] No update needed for this build'
fi
