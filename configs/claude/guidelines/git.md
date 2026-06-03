# Git guidelines

- **Match the repo's commit style.** Mirror the existing history's message
  format (subject style, mood, length) and branching workflow rather than
  imposing a different convention.
- **Atomic commits.** One logical change per commit; don't bundle unrelated
  edits together.
- **Explain the why.** Keep the subject concise and imperative; use the body to
  say why the change was made when it isn't self-evident.
- **Don't co-author the commits.**
- **Stage deliberately.** Check `git status` / `git diff` and stage only the
  intended changes — avoid blindly committing unrelated working-tree edits.
- **Never commit secrets or generated artifacts.** No credentials, `.env`
  files, build output, or dependency directories.
