#!/bin/bash -Eeu

# /etc/ts is where the whole TypeScript toolchain lives, compiler here and test
# framework added by whichever image builds on this one. One prefix rather than
# two, because a start-point symlinks it in as its node_modules and node finds
# a package only by looking there.
#
# A version is named, which the other language images do not do. The test
# frameworks are what decide it: ts-jest declares a peer range of
# "typescript >=4.3 <7", so an unnamed version installs the current 7.x here
# and then no image built on this one can add ts-jest at all. 6 is the newest
# both frameworks accept.
npm install --prefix /etc/ts 'typescript@^6'

# Read by the sandbox user when a kata runs, and written to by nothing, but the
# image that builds on this one adds packages beside them, so ownership is set
# again there.
chown -R sandbox /etc/ts

# Records the TypeScript this image holds, in the shape every image shares.
# The installed compiler is asked, so the version is one the image can run
# rather than the range named above. tsc --version prints "Version 6.0.3".
readonly LANGUAGE_VERSION=$(/etc/ts/node_modules/.bin/tsc --version | cut -d' ' -f2)

if [ -z "${LANGUAGE_VERSION}" ]; then
  echo 'Could not read a version from tsc --version' >&2
  exit 1
fi

cat > /versions.json <<EOF
{
  "language": {
    "name": "TypeScript",
    "version": "${LANGUAGE_VERSION}"
  },
  "test_frameworks": []
}
EOF
