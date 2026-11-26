# Colour Role System

Role-based colour enforcement for bash. Roles like `errors`, `success`, and
`typescript` map to hex values in one schema; a policy file decides which
colours are legal; the shell loader turns them into 24-bit ANSI.

## Install

```bash
git clone https://github.com/top-shelf-service/color.git
cd color
./install.sh
source ~/.bashrc
```

`jq` is the only prerequisite (`sudo apt-get install -y jq`). Re-running
`./install.sh` is always safe — it is idempotent and repairs a damaged install.

## Layout

```
~/.local/share/tss/color/          runtime  ($XDG_DATA_HOME/tss/color)
├── color_roles.json               role -> hex  (your data; preserved on upgrade)
├── laws/color/color-laws.json     policy       (code; refreshed on upgrade)
├── colors.source.sh               loader       (code)
├── install_hook.sh                role registration (code)
├── validate_color_roles.sh        enforcement engine (code)
└── cache/roles.sh                 compiled lookup table (generated)

~/ctl_environment      -> runtime          compatibility symlink, not load-bearing
~/.color_roles.json    -> color_roles.json compatibility symlink, not load-bearing
```

The loader derives its runtime directory from its own path. Delete both compat
symlinks, move the runtime anywhere, and it still works.

## Minimal management CLI

After a one-time normal install from a trusted Git checkout, `color update` fetches that checkout's `origin/main`, stages the existing runtime, runs the existing installer and validator on the candidate, then replaces the live runtime and reloads the calling shell. The prior runtime is retained inside a sibling `.color-backup.*/runtime` directory. A per-runtime update lock rejects overlapping updates; normal failures and catchable signals attempt to restore the prior runtime. A hard kill or power loss during replacement may require manual recovery from the retained backup; a stale lock is deliberately not removed automatically. The source checkout is not modified (only Git fetch metadata changes). The runtime-only update preserves role data, personal aliases, shell startup files and Nano settings; shipped runtime policy and code are refreshed. External schema/law overrides and symlinks inside the runtime are rejected. Git is required for update only. Use `color help`, `color version`, `color list`, and `color validate` for the other commands. Other CLI features remain deferred in GitHub issues.

## Commands

| Command | Does |
|---|---|
| `color_apply <role> "text"` | Print text in that role's colour |
| `color_ls [path ...]` | Semantic long filesystem listing with matching classification symbols |
| `color_roles` / `colorroles` | List every role with a colour sample |
| `colortest` | Print one sample per common role |
| `color_validate` | Check the live schema against the policy |
| `color_reload` | Rebuild the cache after editing the schema |
| `validate_color_roles.sh --emit-constraints` | Print the colour policy as shell assignments |
| `color_doctor` | Print resolved paths, versions and `COLOR_*` env — start here if something looks wrong |
| `install_hook.sh <role> <category> <hierarchy>` | Register a new role |

Registering a role, with an explicit colour or an auto-generated one:

```bash
~/.local/share/tss/color/install_hook.sh nginx infrastructure parent
~/.local/share/tss/color/install_hook.sh nginx infrastructure parent --hex "#3A7BD5"
~/.local/share/tss/color/install_hook.sh nginx infrastructure parent --replace
```

Either way the candidate schema is validated against `color-laws.json` **before**
the write is committed. A rejected colour leaves your schema byte-identical.

## Technical vocabulary

See [Vocabulary library](docs/VOCABULARY.md) and its [canonical JSON](docs/vocabulary.json) for definitions, examples, existing hierarchy meanings and concept relationships. Vocabulary is independent of color registration.

## Policy

`laws/color/color-laws.json` holds policy only — no colour data, so it cannot
drift from the schema. `validate_color_roles.sh` is the single engine that reads
it; `install.sh` and `install_hook.sh` both call that engine rather than
reimplementing checks.

| Rule | Default |
|---|---|
| `require_hex_format` | on — `^#[0-9A-Fa-f]{6}$` |
| `forbid_pure_white` / `forbid_pure_black` | on |
| `forbid_duplicate_roles` | on |
| `require_contrast_ratio` | on — 4.5:1 against `#1E1E1E` |
| `require_luminance_range` | on — perceived luminance 24–247 |
| `require_fields` | on — `role`, `category`, `hex_value`, `hierarchy` |
| `forbid_duplicate_hex` | off (advisory; `--strict` to enforce) |
| `required_roles` | `directory files scripts links prompt errors warnings success` |
| `allowed_hierarchies` | `parent child cousin alert feedback language runtime` |

`require_contrast_ratio` is the rule that reflects real legibility: it measures
WCAG relative contrast against a **declared terminal background**. If your
terminal is light, set `background` to it and the rule will start rejecting the
bright roles instead. `require_luminance_range` is a background-independent
guard that uses luminance rather than per-channel limits, so saturated terminal
semantics like `#FF0000` stay legal while `#0A0A0A` does not. Tighten a rule and both the
installer and the role generator tighten with it automatically.

### Rendering contract: semantic identity and symbol inheritance

Color identifies an object's semantic role. Classification suffixes (such as `*`, `/`, `@`, `|`, `=` and `>`) inherit the associated filename's role color; they must not fall back to the terminal's default foreground or introduce an unregistered pure-white color. Execution and permission attributes remain visible through classification symbols and long-list permission metadata, not by overriding the object's identity color. Broken links use the errors role. This rendering contract is checked by `scripts/test-filesystem-rendering.sh` in CI and the local gate; the JSON color laws still validate role data, not rendered bytes.

Use `color_ls` or `color_ls ~/color` for the managed GNU `ls -alF` view. It accepts paths, not options, and uses the existing schema without modifying ambient `LS_COLORS`. It deliberately leaves native `ls` aliases and metadata unchanged; pipes and `NO_COLOR` or `TERM=dumb` remain plain. Native `ls` remains available for other options. No new roles are required.

### Visual hierarchy: identity and attention (C05)

The existing role is the source of foreground color. The accepted [vocabulary](docs/vocabulary.json) defines what concepts mean; it does not automatically create roles or assign colors. Existing hierarchy values retain their meanings. They are classification labels, not a numeric brightness scale or a requirement that all members share one hue.

For the first enhancement, use one additional visual distinction in the existing `color_apply` text renderer: the `alert` and `feedback` hierarchies receive bold emphasis (SGR 1) in addition to their existing foreground RGB color. Other hierarchies retain normal text weight. This separates operational signals from ordinary object identities, including warnings from JavaScript and success from Node.js, without changing any accepted hex value. The hierarchy comes from the existing role schema; do not add a per-role style field, new hierarchy value, mandatory color-distance threshold or separate palette. Do not imply that bold increases the measured WCAG contrast ratio.

| Positive example | Negative / contrast example |
|---|---|
| `color_apply warnings "[WARNING] retry needed"` uses the warning role RGB and bold. | `color_apply javascript "app.js"` uses its own RGB without added bold. |
| `color_apply success "[SUCCESS] validation passed"` uses the success role RGB and bold. | `color_apply nodejs "node"` uses the Node.js role RGB without added bold. |
| `color_apply errors "[ERROR] operation failed"` uses the error role RGB and bold. | A normal file, directory, link, script or language does not acquire alert emphasis merely because its hue is similar. |

C06 implementation contract: derive emphasis from the installed hierarchy using the existing loader/cache, keep the current role foreground bytes unchanged, reset style after the text, and preserve plain redirected output and unknown-role fallback. Verify a newly registered alert role also receives the same emphasis; verify non-alert roles, adjacent text after reset, and the existing filesystem suffix renderer are unaffected. Use the current contrast floor and existing validator; do not add a new color-law engine. Keep explicit message text meaningful even without color. This behavior is available in 3.2.0. The filesystem renderer retains its existing identity and suffix contract.

## Installer flags

```
--runtime-dir <path>   Install elsewhere (default $XDG_DATA_HOME/tss/color)
-f, --force            Replace user data too (color_roles.json, .bash_aliases)
-b, --backup           Back up anything --force replaces
--skip-aliases         Skip ~/.bash_aliases
--skip-nano            Skip nano TS/TSX syntax
--no-prompt            Leave PS1 alone
--strict               Treat advisory warnings as failures
```

Code files are refreshed on every run; `color_roles.json` and `.bash_aliases`
are your data and are only replaced under `--force`. That split is why upgrading
never eats roles you registered.

## Uninstall

```bash
./uninstall.sh          # -y to skip prompts, --keep-aliases to keep ~/.bash_aliases
```

Removes the runtime wherever it actually lives and strips only the block between
the `# >>> color role system >>>` sentinels in `.bashrc`. Nothing else is touched.

## Docker

```bash
docker build -t color-module-env .
docker run -it color-module-env
```

## Upgrading from 2.x

Run `./install.sh`. A pre-3.0 `~/ctl_environment` directory is migrated into the
runtime with your registered roles intact, and `~/ctl_environment` becomes a
symlink. The old `.bashrc` lines are replaced by a single managed block.

The wrapper scripts `install_aliases.sh`, `install_core.sh`, `install_prompt.sh`,
`install_runtime.sh`, `bootstrap_color_env.sh` and `install_color_aliases.sh`
are gone — all of them were thin duplicates of `install.sh`. Their behaviour is
now flags:

| Was | Now |
|---|---|
| `install_aliases.sh` | `install.sh --skip-nano` |
| `install_core.sh` | `install.sh --skip-aliases --skip-nano --no-prompt` |
| `install_prompt.sh` | `install.sh --skip-aliases --skip-nano` |
| `install_runtime.sh --runtime-dir X` | `install.sh --runtime-dir X` |
| `bootstrap_color_env.sh` | `install.sh` |

## License

MIT — see [LICENSE](LICENSE).
