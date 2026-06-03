# Code guidelines

- **Research before hand-rolling.** Prefer an existing, well-supported tool,
  library, or language built-in over a custom implementation — look for one
  before writing new code.
- **Reuse Tailwind Plus widgets.** All Tailwind Plus widgets live under
  `/home/bhe/Documents/projects/tailwind-plus` — check there before building UI
  components.
- **Match local conventions.** Follow the surrounding code's and the repo's
  existing patterns, naming, and idioms rather than inventing new ones.
- **Keep changes minimal and idempotent.** Prefer guarded, re-runnable edits;
  touch only what the task needs.
- **Do not clutter the source code with comments.** Have the code speak for itself.
- **Pass the linters.** Every source and text file must pass its configured
  linter/formatter.
