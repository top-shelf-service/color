# 2.0.5 → 3.1.0

Run `./install.sh`. It migrates a pre-3.0 `~/ctl_environment` into the runtime
with your registered roles intact. Nothing else is required.

## Set the executable bits in git

Zip and rsync do not carry git's mode bits, and the missing bits are what broke
every wrapper on a fresh clone in 2.x. After copying this tree over:

```bash
git update-index --chmod=+x \
  install.sh uninstall.sh validate_color_roles.sh gate.sh \
  ctl_environment_template/install_hook.sh.template
git ls-files -s | awk '$1!="100644"'      # should list exactly those five
```

CI now asserts this, so a regression fails the build.

## Deleted

| File | Why |
|---|---|
| `install_color_aliases.sh` | 607-line second installer duplicating `install.sh` |
| `install_core.sh` | `install.sh --skip-aliases --skip-nano` |
| `install_prompt.sh` | byte-identical copy of `install_core.sh` |
| `install_aliases.sh` | deprecated wrapper that just called `install.sh` |
| `install_runtime.sh` | folded into `install.sh --runtime-dir` |
| `bootstrap_color_env.sh` | wrapper around a wrapper around `install.sh` |
| `scripts/bootstrap/install_aliases.sh` | third alias installer, same name as a second one |
| `README.mdy` | byte-identical duplicate of `README.md` |

Flag equivalents are in the [reference guide's upgrade table](docs/REFERENCE.md#upgrading-from-2x).

## Behaviour changes

**Runtime moved** to `$XDG_DATA_HOME/tss/color` (`~/.local/share/tss/color`).
`~/ctl_environment` and `~/.color_roles.json` remain as symlinks, but nothing
resolves through them — the loader finds its runtime from its own path. You can
delete both.

**`.bashrc` is now one managed block** between `# >>> color role system >>>`
sentinels, rewritten wholesale each install. Old 2.x lines are replaced.
Uninstall removes only what is between the sentinels.

**`color-laws.json` is v2 and policy-only.** The duplicated role→hex map is
gone; that duplication is what let the two files drift. A v1 laws file is
detected, warned about, and ignored in favour of built-in defaults until you
re-run `install.sh --force`.

**Installs now fail closed.** A schema violating the policy aborts the install
with a non-zero exit. `--force` resets the schema to the shipped palette.

**`install_hook.sh` validates before committing.** A rejected colour leaves your
schema byte-identical. It also takes `--hex "#RRGGBB"` to request a specific
colour, which must itself pass policy.

**`colortest` was printing two uncoloured lines.** It referenced roles `error`
and `warning`; the schema defines `errors` and `warnings`. Fixed.

## Fixed in 3.0.1

**Existence checks no longer use `jq -e`.** Its exit status conflates three
outcomes — 0 found, 1 last value false/null, 4 no output — which makes it the
wrong tool for "does this role exist". Replaced with `any(.[]; .role == $r)`,
which emits exactly one boolean. This appeared in the hook's duplicate check,
the validator's required-roles check, two gate assertions and one CI step. The
validator one was the dangerous one: a misread there would silently stop the
missing-required-role law from firing, and a policy engine that quietly stops
enforcing is worse than one that errors.

**The "already exists" error now names the file it inspected**, prints the entry
it matched, and dumps any `COLOR_*` variables in your environment. If the hook
ever refuses a role you know is absent, the message itself tells you which
schema it was reading.

**`install_hook.sh --replace`** overwrites an existing role rather than
refusing. Replacing does not grow the schema.

**The hook warns when `COLOR_ROLE_SCHEMA_PATH` overrides its own runtime**
instead of silently obeying it.

**The gate scrubs `COLOR_*` from every invocation** (`env -u`). If your
interactive shell has the colour system loaded, `COLOR_ROLE_SCHEMA_PATH` points
at your real schema — without scrubbing, every case would test the wrong file.
Case 21 is a regression test that deliberately poisons the environment and
asserts the hook still writes to its own runtime.

**`color_doctor`** prints resolved paths, role counts, jq and bash versions, and
`COLOR_*` env in one shot.

**Gate portability.** The jq-less case built its sandbox by hardcoding
`PATH=/usr/bin:/bin`, which does not hide jq on Debian — jq lives in `/usr/bin`
alongside coreutils, so the case failed on a false premise. It now builds a temp
directory of symlinks that deliberately excludes jq. The YAML case reports SKIP
rather than FAIL when pyyaml is absent, since a missing linter is not a broken
product.

**Gate verified under jq 1.7 and jq 1.7.1**, 32/32 on both.

## Fixed in 3.0.2 — performance

**The hook no longer brute-forces past non-colour errors.** An invalid
hierarchy used to send the generator through its full 200-attempt budget,
invoking the whole validator each time, every attempt failing for a reason no
new colour could fix. Attributes are now pre-flighted once and rejected
immediately: **23.5s → 54ms** here, and it was 67s on arm64.

**Candidate colours are tested in-process.** `validate_color_roles.sh
--emit-constraints` hands the policy to the caller as shell assignments; the
hook then filters candidates with integer arithmetic and calls the engine once
for the authoritative verdict. The laws file is still the only place rules
live — only their extraction moved. Retry budget dropped 200 → 64 because a
compliant colour is found in one or two tries.

**The validator makes 15 jq calls instead of 41.** The whole policy loads in
one call rather than one per rule, and all per-entry rules run as a single jq
program. **114ms → 47ms per validation**, which also speeds up every install.

**Gate: 39s → 11s**, and it now owns the negative-law matrix (case 5) instead
of leaving it to CI only.

### A caution, recorded because it nearly shipped

Consolidating the rules silently deleted the missing-required-role check, and a
first attempt at rewriting it used `index(.)` after a pipe, which rebinds `.` to
the array itself so the law could never fire. Both times the positive test still
passed — a clean schema validated fine. Only the negative matrix caught it.
Any change to the validator must be checked from the negative side; that is now
enforced locally, not just in CI.

## New in 3.1.0 — readable palette, enforced

Five roles failed WCAG body-text contrast on a dark terminal. `directory` and
`prompt` also shared one hex, so they were indistinguishable.

| role | was | ratio | now | ratio |
|---|---|---|---|---|
| directory | `#A020F0` | 3.14 | `#B858F4` | 4.56 |
| prompt | `#A020F0` | 3.14 | `#FA99C3` | 8.26 |
| scripts | `#4169E1` | 3.44 | `#FF9E4A` | 8.13 |
| typescript | `#007ACC` | 3.70 | `#42B3FF` | 7.24 |
| errors | `#FF0000` | 4.17 | `#FF2E2E` | 4.51 |

`scripts` moved out of blue entirely — `files`, `links` and `typescript` were
already blue-ish, so lightening it would have been readable but not distinct.
Orange was the one unused hue family. All eleven roles now clear 4.5:1, no two
share a hex, and the closest pair in Lab space is warnings/javascript at ΔE 18
(both yellow by convention — brand colours left alone).

**`require_contrast_ratio` is a real law now.** It measures WCAG relative
contrast against a declared `background`, defaulting to `#1E1E1E`. Change that
value to your actual terminal colour and the rule re-aims — a light terminal
will start rejecting the bright roles instead. The validator computes it
exactly; the hook gets the threshold plus a 256-entry sRGB linearisation table
from `--emit-constraints`, so it filters candidates with integer arithmetic and
no extra subprocess.

**Upgrades fail closed.** If a role you registered under 2.x does not meet the
new floor, `install.sh` aborts and prints three ways out: recolour that one role
with `install_hook.sh <role> ... --replace`, reset with `--force`, or edit the
laws file. That is deliberate — silently rewriting your colours would be worse.

**If your terminal is light**, set `rules.require_contrast_ratio.background` to
its colour and run `color_validate`. Several roles will fail, correctly.

## Verify

```bash
./gate.sh     # 35 cases: static, install, contract, enforcement, self-heal, uninstall
```

Needs `jq`. `shellcheck` and `python3`+`pyyaml` are optional — those cases
report SKIP rather than FAIL when absent. Every case runs against a throwaway
`$HOME`; nothing touches your real environment.

## Measured

| | 2.0.5 | 3.0.0 |
|---|---|---|
| bytes exported into every child process | 2207 | 0 |
| 50 `color_apply` calls | 208 ms | 4 ms |
| 30 loader loads | ~313 ms | ~301 ms |

Per-call cost drops because roles compile once into `cache/roles.sh` and lookup
is a bash array rather than two `jq` forks. Loader startup is unchanged within
noise — the win is per call and in the environment footprint, not at login.
`jq` is needed at install time and whenever the schema changes, not at every
shell start.
