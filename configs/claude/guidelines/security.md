# Security guidelines

- **Never expose secrets.** Keep credentials, tokens, and keys out of source,
  logs, and error output; read them from env vars or a secret manager.
- **Distrust external input.** Validate and sanitize anything from users,
  network, files, or the environment before using it.
- **Avoid injection.** Use parameterized queries and safe APIs; never build SQL,
  shell, or HTML by concatenating untrusted input.
- **Least privilege.** Request the narrowest permissions, scopes, and file
  access the task needs; don't broaden them for convenience.
- **Use vetted crypto.** Rely on established libraries for hashing, encryption,
  and randomness — never hand-roll cryptographic primitives.
- **Fail safe.** On error, deny by default and don't leak internals (stack
  traces, secrets, system details) to users.
