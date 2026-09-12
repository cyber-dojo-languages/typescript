# Shipping node's compile cache in the image

Adopted here. `cyber-dojo-languages/javascript/docs/node-compile-cache.md`
measured the same idea for the images built on `javascript-node` and did not
adopt it, because the gain did not justify the nine repos it touched. The
TypeScript images have their own base image now, so the setting is one line in
one repo that two LTF images inherit, and those two were the slowest of the
family.

## Where the time went

Stages of one kata run, in a fresh container, before any of this:

| stage        | typescript-jest | typescript-vitest |
|--------------|-----------------|-------------------|
| node startup | 35ms            | 25ms              |
| tsc --noEmit | 408ms           | 434ms             |
| test run     | 384ms           | 315ms             |

The compiler is the largest stage in both, and neither stage is doing much
work: they are mostly node compiling the JavaScript that tsc, jest and vitest
are written in. That is what `NODE_COMPILE_CACHE` removes.

## What it is worth

One run per fresh container, alternating between the two images so drift over
the measuring period could not favour either, milliseconds per run:

    typescript-jest   published  816 864 655 630 608 645 629 631
                      warmed     710 590 541 566 551 527 546 535

    typescript-vitest published  865 762 800 681 764 684 703 689
                      warmed     713 646 638 689 643 608 654 629

About 85ms for jest and about 55ms for vitest. The cache costs 4.8MB in 194
files, and 3.1MB in 111 files.

typescript-jest also stopped asking jest for worker processes. Against the same
image, alternating between a start-point running `--maxWorkers=2` and one
running `--runInBand`:

    maxWorkers=2   705 583 597 591 607 581
    runInBand      598 558 568 548 562 533

About 35ms, and every run of the second beat the run of the first beside it.
Starting a worker costs more than a kata's one test file takes to run.
typescript-vitest already ran single-worker, through `fileParallelism: false`
in its vitest.config.ts.

## The trap: node partitions the cache by user id

Node names the cache directory after the uid that wrote it, so a cache warmed
as root is one the sandbox user cannot read. A kata then recompiles everything
and writes a second full copy, which the javascript measurements found to be
slower than having no cache at all.

Two places root would have written one, and what stops it:

- the base image's own `npm install`. `ENV NODE_COMPILE_CACHE` is set after
  that line rather than before it, so npm never sees the variable. Setting it
  earlier produced a `...-0` directory beside the `...-41966` one, megabytes
  that no kata ever reads.
- each LTF image's `npm install`, which inherits the setting from the base.
  Those run under `env --unset=NODE_COMPILE_CACHE`.

Each `warm_node_compile_cache.sh` checks both halves of this before the build
is allowed to continue: that the directory just written is named for the uid
running the script, and that a second run beat the first. Either check failing
means the cache is costing image size and giving nothing back.

## How to measure it, if this is revisited

One run per fresh container, alternating between the images under comparison.
Best-of-N inside a single container measures runs 2..N, which do not exist in
production, and reports a speedup that is not there.
