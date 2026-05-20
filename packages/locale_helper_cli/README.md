# locale_helper_cli

The `locale_helper` command-line tool. Developers run this in their
Flutter project to publish ARBs to reviewers and pull approved changes
back.

## Install

```bash
dart pub global activate locale_helper_cli
```

This package is published to pub.dev. The copy in this monorepo is the
source of truth; the public mirror at `mohn93/locale_helper_cli` is a
subset (`packages/locale_helper_cli/` + `packages/locale_helper_shared/`)
kept in sync manually. Releases require publishing **both** packages —
`locale_helper_shared` first, then `locale_helper_cli`. See the root
[CLAUDE.md](../../CLAUDE.md) for the release workflow.

## Commands

| Command                | What it does                                          |
|------------------------|-------------------------------------------------------|
| `locale_helper signup` | Create an account against the API                     |
| `locale_helper login`  | Sign in; stores a token in `~/.locale_helper/`        |
| `locale_helper logout` | Forget the stored token                               |
| `locale_helper init`   | One-time per-project wizard; writes `.locale_helper/` |
| `locale_helper publish`| Pushes ARBs + AI-generated context to the API         |
| `locale_helper pull`   | Pulls approved changes; `--apply` writes them to ARBs |
| `locale_helper status` | Shows current project + auth state                    |

Source for each lives under `lib/src/commands/`. Shared plumbing —
`api_client.dart`, `arb_loader.dart`, `baseline_lock.dart`,
`credentials.dart`, `project_config.dart`, `usage_scanner.dart` —
sits in `lib/src/`.

## State on disk

Two locations:

- `~/.locale_helper/credentials.json` — auth token. Global, per-user.
- `<project>/.locale_helper/` — per-project. Holds the project id and
  the **baseline lockfile** that makes concurrent edits safe (publish +
  pull both consult it).

Both files are written by the CLI; nothing in them is meant to be
hand-edited.

## Run

From source against a local API:

```bash
dart run bin/locale_helper.dart --api-url http://localhost:8080 init
```

The `--api-url` flag overrides the default production URL
(`https://api.locale.ly`). Useful when running against `dart_frog dev`
or the dev proxy on `:5050`.

## Test

```bash
dart test
```

Pure-Dart, no Postgres needed. HTTP calls are stubbed with
`http.MockClient`.
