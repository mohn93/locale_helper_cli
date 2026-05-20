# locale_helper_shared

Pure-Dart DTOs and value types shared by the CLI, the server, and the
Flutter web app. No I/O, no Flutter, no platform code — just data
shapes and small parsers/serializers (ARB, ICU MessageFormat, CLDR plural
rules) that need to behave identically on every surface.

## What lives here

| File                              | What                                                       |
|-----------------------------------|------------------------------------------------------------|
| `arb.dart`                        | ARB file parsing + serialization                           |
| `bundle.dart`                     | The on-disk bundle format devs publish + reviewers see     |
| `icu.dart` / `cldr.dart`          | ICU MessageFormat + CLDR plural-rule helpers               |
| `string_entry.dart`               | A single string + its metadata across locales              |
| `edit.dart` / `string_change.dart`| Reviewer edits and the change history they produce         |
| `auth_dtos.dart`                  | Signup/login request + response shapes                     |
| `user_dto.dart` / `membership_dtos.dart` / `comment_dto.dart` / `project_list_item_dto.dart` / `review_state_dto.dart` | API DTOs |
| `role.dart` / `usage.dart`        | Enums + small value types                                  |
| `dtos.dart`                       | Barrel — exports everything                                |

## Run tests

```bash
dart test
```

Pure-Dart, runs on the VM. No Postgres, no Flutter.

## Adding a new DTO

1. Add the model under `lib/src/`.
2. Re-export it from `dtos.dart` if it's part of the public API surface.
3. Mirror it in `mohn93/locale_helper_cli` (the public CLI repo) if the
   CLI consumes it — see the root [CLAUDE.md](../../CLAUDE.md) for the
   manual sync procedure.
