# The Omega seed-chain bootstrap challenge

Rebuild the Omega compiler from 408 hand-written bytes on your own machine, and check that every rung
comes out byte for byte the same as the published values. Measured times for the rebuild-and-check:
0.42 s wall on a DGX Spark (2 cores, from a fresh clone,
[log](results/drakestapleton-spark-gb10-20261027.log)) and 0.47 s on a GitHub `ubuntu-24.04-arm`
runner ([run](https://github.com/aien-dev/omega-seed-challenge/actions/runs/40426178383)).

```
seed0.hex --load0.sh (POSIX printf)--> seed0 (408 B) --> hex1 (776 B) --> asm2 (2,464 B)
          --> om4 (14,224 B) --> omc --> omc --> omc (325,524 B, all three identical)
```

No C compiler, assembler or linker writes a byte of this chain. Each rung is a program written by the
rung below it, starting from 408 bytes you can read word by word in
[`seed/rung0/seed0.hex`](https://github.com/aien-dev/omega-mv/blob/369dbc96daa1684db2d7c2c7085bbf16b3fd77ee/seed/rung0/seed0.hex).
The checker and the source live in [aien-dev/omega-mv](https://github.com/aien-dev/omega-mv)
(`seed/challenge/`). This repository is where you can watch it pass and post your own result.

[![seed-chain challenge](https://github.com/aien-dev/omega-seed-challenge/actions/workflows/challenge.yml/badge.svg)](https://github.com/aien-dev/omega-seed-challenge/actions/workflows/challenge.yml)

## Run it

You need AArch64 Linux: a Raspberry Pi 4/5 on a 64-bit OS, an Ampere or Graviton machine, an arm64 Linux
VM on Apple silicon, or a DGX Spark. You also need `git`, `sh`, `awk`, `sed`, `tar` and coreutils. You
don't need root or a compiler, and nothing is downloaded after the clone.

```sh
git clone https://github.com/aien-dev/omega-mv
cd omega-mv
git fetch origin pull/863/head && git checkout FETCH_HEAD   # only until omega-mv PR #863 merges
sh seed/challenge/run.sh
```

The last line is `CHALLENGE PASS pin=369dbc96… omc=2c824805…` (exit 0) or `CHALLENGE FAIL` (exit 1).
On any other architecture it prints `CHALLENGE NOT_RUN` (exit 3). The seed programs are AArch64 Linux
ELF files, and the script never emulates them. The hash log is `build/seed/challenge/challenge.log`.
The script builds from `git archive` of the pin into `build/`, and it never rewrites a tracked file.

## The published values

These come from omega-mv source commit `369dbc96daa1684db2d7c2c7085bbf16b3fd77ee`. Each value is the
sha256 of the file committed at that pin, read with `git show <pin>:<path> | sha256sum` before anything
was rebuilt.

| Rung | Written by | Bytes | sha256 |
|---|---|---:|---|
| seed0 | `load0.sh` from `seed0.hex` | 408 | `aca00cf3677236809f0f223437398c6bb429e4c65f13d58762bcf96d13799474` |
| hex1 | seed0 from `hex1.hex` | 776 | `920e1756aec399c7c74f5cedd1676abb91b844ea75448e14aa50dcb0bbc7ba5d` |
| asm2 | hex1 from `asm2.hex1` | 2,464 | `6988abe072fac3cdef2240d5ad13a3ecd8fb576fa09112d344b9e7c2315969c4` |
| om4 | asm2 from `table.s2 table3.s2 table4.s2 om4.s` | 14,224 | `d0da40e45f1fcc45d9a39c9c52c9d745b545e076970729e51c12d76ef519efab` |
| omc, stages 1-3 | om4, then omc itself, from `seed/omc/omc.om` | 325,524 | `2c82480596bbdc50cda9626866209ef662d5834f278f839ff4ce0250c495029f` |

The full table, including the nine input files, is
[`seed/challenge/expected.txt`](https://github.com/aien-dev/omega-mv/blob/06191fde568dfdcf9797133b867caed7d6cd3a59/seed/challenge/expected.txt).

## Watch it pass

[`challenge.yml`](.github/workflows/challenge.yml) runs on a GitHub-hosted `ubuntu-24.04-arm` runner
on every push and pull request, and also weekly and on demand. It runs the challenge, and the challenge
must PASS. It then runs three negative controls, and each one must fail:

1. A tampered rung: one word of `hex1.hex` is changed (the ELF ABI-version byte, which Linux ignores).
   hex1 still runs, but its hash no longer matches, and the run ends `CHALLENGE FAIL`.
2. A wrong published value: one digit of the omc hash is changed, and all three omc stages FAIL.
3. A forged log: one hash in a passing log is changed, and `check-result.sh` refuses it.

The log of each run is in the job summary and in the `challenge-log` artifact.

## Post your result

- **Issue:** open an [I reproduced it](../../issues/new?template=reproduced.yml) issue and paste your
  `challenge.log`. A workflow checks it against the table and replies with the verdict.
- **Pull request:** add your log as `results/<github-user>-<yyyymmdd>.log`. The
  [`result check`](.github/workflows/result-check.yml) workflow runs `check-result.sh` on every log in
  `results/`.

Failed runs are worth posting too. A machine where a rung comes out different is the most interesting
result this challenge can produce.

## What a pass shows, and what it does not

- A pass shows that your machine, starting from 408 readable bytes, produced the same compiler binary
  that is committed in omega-mv, and that the compiler reproduces itself (stage1 = stage2 = stage3).
- It is a fixed-output match. It is not general self-hosting, and it is not diverse double compilation:
  each rung is built by the rung before it, so there is only one path. It also does not show that omc
  compiles every program correctly.
- `check-result.sh` checks that a log is complete and that its hashes are the published ones. A log is
  text, so the check cannot prove that the run happened. The Actions run is the one you can watch.
- The pin is fixed. omega-mv `main` keeps changing `seed/omc/omc.om`, so a new pin needs a new table,
  read from the committed files in the same way.
- The scripts here and in omega-mv `seed/challenge/` are POSIX `sh` host glue. They run the seed
  programs and compare hashes with coreutils `sha256sum`. They are deliberately not written in `.om`,
  because a checker compiled by the chain it checks would be circular.

## License

Apache-2.0, the same as omega-mv. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
