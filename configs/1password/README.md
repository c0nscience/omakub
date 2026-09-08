# REJECTED — do not install

These files were a proposal to suppress the 1Password authorization dialog at
`claude` launch with a polkit rule keyed on the requesting process's cgroup.
Verification on 2026-09-04 killed it on two independent grounds:

1. **It targets an action that never fires on this machine.** Over the whole
   retained journal (since 2026-04-24) polkit recorded 43
   `com.1password.1Password.unlock` authorizations and **zero**
   `com.1password.1Password.authorizeCLI`. Since 2026-08-10 the app has not
   used polkit at all; its own log shows `invoked password unlock in locked
   state`. A rule on `authorizeCLI` would do nothing.

2. **The cgroup test is not a boundary.** `app.slice` under
   `user@1000.service` is cgroup-delegated to benni, so a process inside
   `claude-*.scope` leaves it unprivileged with `systemd-run --user --scope`,
   or by `mkdir`-ing a scope there and writing its own pid into
   `cgroup.procs`. The helper then exits 0 and polkit returns YES. The rule
   is therefore close to an unconditional `authorizeCLI -> YES` while reading
   as if it were confined.

Additionally: the rule never checks `subject.local` / `subject.active`; polkit
124 exposes only a bare `int subject.pid` with no pidfd, so the helper's
re-read of `/proc/<pid>/cgroup` is racy against pid reuse; and if the app
passes *itself* as the subject the rule degrades to unconditional YES.

Kept for the record only. See `~/Documents/notes/op-cli-agentic-workloads.md`
section 7 for what to do instead.
