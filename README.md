# Color

**A role-based terminal color system and technical vocabulary reference for Bash.**

Color makes technical concepts easier to recognize in the terminal through consistent semantic colors, visual emphasis and an integrated learning reference. A central policy validates the palette; runtime maintenance preserves your configuration.

## What it does

- Gives files, directories, scripts, languages and operational messages consistent visual identities.
- Provides a searchable technical vocabulary with definitions and examples.
- Manages, validates, updates and backs up the local color configuration.

## Quick start

Requires Bash on Linux, Git, jq and standard GNU utilities. On Debian or Ubuntu, install missing dependencies with `sudo apt-get install git jq`.

```bash
git clone --branch v3.4.0 https://github.com/top-shelf-service/color.git
cd color
./install.sh
source ~/.bashrc
color doctor
```

## Everyday use

```bash
color help
color_ls
color man idempotency
color search 'database'
color show directory
color update
```

`color update` follows the trusted checkout's `origin/main` and preserves your role data and personal aliases. For uninstalling while preserving aliases, use `./uninstall.sh --keep-aliases`.

## Documentation

- [User and technical reference](docs/REFERENCE.md) — commands, configuration, recovery, policy and rendering.
- [Technical vocabulary](docs/VOCABULARY.md) — definitions, structure and design.
- [Upgrade notes](UPGRADE.md) — migration and release history.

## Project status

Stable release: [v3.4.0](https://github.com/top-shelf-service/color/tree/v3.4.0). Verified by CI, Docker and local Chromebook acceptance. Runtime development is frozen; further changes require a demonstrated need.

## License

[MIT](LICENSE).
