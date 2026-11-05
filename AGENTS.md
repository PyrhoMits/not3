# Repository agent instructions

## Shell preference

- Use Fish syntax for user-facing local shell commands and new shell scripts by
  default.
- Use another shell only when the execution environment or an existing project
  file requires it, and identify that shell clearly.

## Local planning documents

- Treat `AI-Planners/` as local planning state. Update its plans and
  `CHANGELOG.md` as work progresses, but do not stage or commit anything under
  `AI-Planners/` unless the user explicitly asks for it.
- Keep planned work at the top level of `AI-Planners/CHANGELOG.md`, followed by
  dated implementation history.

## Flutter environment

- Run Flutter and Dart commands inside the `elated_carver` container, using the
  Flutter SDK at `/sdks/flutter`.
- Do not build an APK unless the user explicitly requests a build.
