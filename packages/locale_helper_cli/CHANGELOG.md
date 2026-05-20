# Changelog

## 0.1.0 — 2026-05-20

- Initial public release.
- `locale_helper init` — wizard that writes `.locale_helper/config.yaml`. When
  the user is already logged in (`locale_helper login`), offers to attach to an
  existing project on the server instead of always creating a new one.
- `locale_helper login` / `logout` / `signup` — manage credentials against the
  locale.ly hosted backend (or your own self-hosted instance).
- `locale_helper publish` — uploads ARB strings + Claude-generated context for
  each key. First publish creates the server-side project; subsequent publishes
  attach to the same project id stored in `.locale_helper/`.
- `locale_helper pull --apply` — writes approved changes back to your ARB
  files. A baseline lockfile detects conflicts before they overwrite local
  edits.
- `locale_helper status` — shows current project + auth state.
