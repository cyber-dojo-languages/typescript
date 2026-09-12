#!/usr/bin/env bash
set -Eeu

readonly MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly REGEX="image_name\": \"(.*)\""
readonly JSON=`cat ${MY_DIR}/docker/image_name.json`
[[ ${JSON} =~ ${REGEX} ]]
readonly IMAGE_NAME="${BASH_REMATCH[1]}"

# docker/install.sh asks npm for the major version only, so a rebuild picking
# up a new minor stops here and names it, rather than changing what the image
# offers without saying so.
readonly EXPECTED="Version 6.0"
readonly ACTUAL=$(docker run --rm -i ${IMAGE_NAME} sh -c '/etc/ts/node_modules/.bin/tsc --version')

if echo "${ACTUAL}" | grep -q "${EXPECTED}"; then
  echo "VERSION CONFIRMED as ${EXPECTED}"
else
  echo "VERSION EXPECTED: ${EXPECTED}"
  echo "VERSION   ACTUAL: ${ACTUAL}"
  exit 42
fi
