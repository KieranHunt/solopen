# solo

Open (or create) the Solo project for a directory, from the shell.

```
solo [--force] <directory>
```

Resolves the directory to a Solo project and brings it up in Solo.app:

1. **Exact match** — a registered project whose path equals the directory
   (after `realpath`).
2. **Deepest ancestor** — the registered project furthest down the tree that
   contains the directory. Catch-all projects on the ignore-list (currently
   just `$HOME`, the `~` project) never ancestor-match, though they still
   open via exact match.
3. **Create** — registers a new project named after the directory's basename,
   rooted at the literal directory (never the enclosing git root), then opens
   it. If registered projects already exist *beneath* the directory the
   create is refused and they are listed; `--force` creates anyway.

If Solo.app isn't running it is launched and polled until the CLI answers
(`SOLO_LAUNCH_TIMEOUT` seconds, default 15). If the app is running but its
local API is unreachable, local CLI access is off in Solo's settings — the
script says so immediately instead of polling.

Installed on PATH via `~/bin/solo → ~/Projects/solo/solo`.
`~/bin/solo-cli → /Applications/Solo.app/Contents/MacOS/solo-cli` exposes the
bundled CLI the script shells out to (override with `SOLO_CLI`).

## Open mechanism (spike, 2026-07-30)

Solo.app registers the `solo://` URL scheme. Tested `open "solo://proj/<id>"`
against the running app (Solo 0.9.3, macOS 26.5):

- `open "solo://proj/6"` foregrounded Solo.app (frontmost switched from
  another app) and selected the **vine** project.
- `open "solo://proj/9"` selected **slo** — switching confirmed on a second id.
- Re-opening the already-selected id is a clean no-op (stays on the project).
- An unknown id (`solo://proj/9999`) does not crash the app; the main pane
  drops to "No project selected". Harmless, but don't feed it bad ids —
  always resolve the id from `solo-cli projects list` first.

**Chosen mechanism:** `open "solo://proj/<id>"` is the primary (and only)
open path. The fallback considered in the spike (`open -a Solo` + printing
the resolved project) is unnecessary.

## Development

Tests use [shellspec](https://shellspec.info/), installed via mise
(`mise.toml`):

```
mise exec -- shellspec
```
