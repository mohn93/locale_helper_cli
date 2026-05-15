# locale_helper_cli

Command-line tool for [locale.ly](https://locale.ly) — translation review for
Flutter apps. Ship your app's ARBs to anyone who can write, review their work
in a web app, pull approved changes back into your repo.

The hosted service lives at locale.ly. This repository contains only the
client-side CLI and its shared types — the server is operated by us.

```
$ locale_helper init               # one-time per project
$ locale_helper publish            # pushes ARBs + Claude-generated context
                                   # reviewers do their thing at app.locale.ly
$ locale_helper pull --apply       # writes approved changes back to your ARBs
```

## Install

```bash
dart pub global activate \
  --source git https://github.com/mohn93/locale_helper_cli \
  --git-path packages/locale_helper_cli
```

(Will move to `dart pub global activate locale_helper_cli` once we publish to
pub.dev.)

Then in any Flutter project with ARB files:

```bash
cd path/to/your/flutter/app
locale_helper init                 # follows the wizard
```

## How it works

Three commands. Your project's `.locale_helper/` directory tracks just enough
state (project id, baseline lockfile) to keep pushes and pulls safe under
concurrent edits.

1. **`locale_helper publish`** — uploads every key in your source ARB to your
   project on locale.ly. Claude generates a short context blurb for each key
   so reviewers understand intent. Other locales already in your ARB folder
   are uploaded as starting drafts.

2. **Reviewers translate** — invite anyone via a link. They edit per-locale
   in the web app, side-by-side with the source. Suggestions wait for owner
   approval; direct edits by owners go through immediately.

3. **`locale_helper pull --apply`** — fetches every approved value and
   rewrites your ARB files in place. A 3-way diff against the baseline keeps
   local edits you made between push and pull safe — conflicting keys are
   surfaced for you to resolve instead of silently overwritten.

## Repository layout

```
packages/
  locale_helper_shared/   pure-Dart types shared by every locale.ly package
  locale_helper_cli/      the `locale_helper` command-line tool
```

Both packages form a Dart workspace; `dart pub get` at the repo root
resolves them together.

## Development

Requirements: Dart 3.6+.

```bash
dart pub get
dart test
```

## Contributing

Issues and PRs welcome. This is a small project; expect quick iteration and
the occasional breaking change while we're pre-launch.

## License

MIT. See [LICENSE](./LICENSE).
