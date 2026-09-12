#!/bin/bash -Eeu

# Run as sandbox when the image is built, never as root.
#
# Node compiles the JavaScript it loads on every start, and writes the result
# to NODE_COMPILE_CACHE when that names a directory it can write. A kata gets a
# fresh container per test run, so a cache a run writes is thrown away with the
# container; warming it here is what lets every run read one.
#
# The compiler is what this image ships, so the compiler is what it warms. An
# image building on this one warms its own test framework on top, into the same
# directory.
#
# Node partitions the cache by user id. A cache warmed as root sits in a
# directory named for root's uid, which the sandbox user cannot read, so a kata
# recompiles everything and then writes a second full copy. That measured
# slower than having no cache at all, which is why this runs as sandbox and why
# the first check below exists.

readonly WARM=/tmp/warm-typescript
mkdir -p "${WARM}"
cd "${WARM}"

cat > warm.ts <<'EOF'
export function answer(): number {
  return 6 * 7;
}
EOF

cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "strict": true,
    "skipLibCheck": true,
    "target": "es2022",
    "lib": ["es2022"]
  }
}
EOF

milliseconds()
{
  local -r start="$(date +%s%N)"
  "$@" > /dev/null 2>&1
  local -r finish="$(date +%s%N)"
  echo "$(( (finish - start) / 1000000 ))"
}

readonly TSC=/etc/ts/node_modules/.bin/tsc
readonly COLD="$(milliseconds "${TSC}" --noEmit)"
readonly WARMED="$(milliseconds "${TSC}" --noEmit)"

echo "tsc cold ${COLD}ms, warmed ${WARMED}ms"
ls "${NODE_COMPILE_CACHE}"

# Named for the uid that wrote it. Anything else means this ran as the wrong
# user and a kata will not read a byte of what was just written.
if [ -z "$(ls "${NODE_COMPILE_CACHE}" | grep -- "-$(id -u)\$")" ]; then
  echo "compile cache was not written by uid $(id -u)"
  exit 42
fi

# A cache that is not read is a cache that costs image size and gives nothing
# back. The second run has to beat the first.
if [ "${WARMED}" -ge "${COLD}" ]; then
  echo "warmed run (${WARMED}ms) did not beat the cold one (${COLD}ms)"
  exit 42
fi
