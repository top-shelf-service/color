# Roadmap

## Done (3.0.0)

**Installer surface collapsed to one script.** `install.sh` absorbed
runtime-dir handling, prompt selection, aliases and nano syntax. Six wrapper
scripts were deleted; every one was a thin duplicate. Fewer entrypoints means
fewer ways for them to disagree with each other, which is how the 2.x docs
drifted from the code.

**Runtime separation is real, not cosmetic.** `colors.source.sh` derives
`COLOR_RUNTIME_HOME` from its own path. The `~/ctl_environment` and
`~/.color_roles.json` symlinks are conveniences; nothing resolves through them.
Deleting both, or relocating the runtime, is covered by CI.

**Policy is enforced.** `color-laws.json` is policy only — the duplicated
role→hex map that let the two files drift is gone. `validate_color_roles.sh` is
the single engine, called by `install.sh` and `install_hook.sh`. Installs fail
closed on a violating schema; role registration validates before committing and
rolls back on failure. CI asserts that every individual law rejects a crafted
violation.

**Code/data split.** Loader, hook and validator are refreshed on every install.
`color_roles.json` and `.bash_aliases` are preserved unless `--force`. Roles you
registered survive upgrades.

**Managed `.bashrc` block.** Sentinel-delimited and rewritten wholesale, so
re-running never appends duplicates and uninstall never touches your own lines.

**No jq at shell start.** Roles compile once into `cache/roles.sh`;
`color_apply` is a bash array lookup instead of two subprocesses per call.

**Soft failure.** A missing schema, absent jq or unwritable cache degrades to
uncoloured output with one warning. Sourcing the loader cannot break a login
shell.

## Next

- Contrast checking against a declared terminal background, not just absolute
  luminance.
- `color_apply` support for background and style attributes (bold, underline).
- A `--dry-run` mode on `install.sh` that reports what would change.
- Publish tagged releases; the 2.x watchdog/updater assumed a release archive
  that was never produced.
