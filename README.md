# Colour Role System

Role-based colour enforcement for bash. Roles like `errors`, `success`, and
`typescript` map to hex values in one schema; a policy file decides which
colours are legal; the shell loader turns them into 24-bit ANSI.

## Install

```bash
git clone https://github.com/peteywee/color.git
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
