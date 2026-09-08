#!/bin/bash
# DISABLED. See README.md in this directory.
# This rule was rejected on 2026-09-04: it targets a polkit action that never
# fires on this machine, and its cgroup test is escapable by the very process
# it is meant to restrain. Installing it would be close to granting
# com.1password.1Password.authorizeCLI unconditionally.
echo "REFUSING TO INSTALL: this polkit rule was rejected. Read $(dirname "${BASH_SOURCE[0]}")/README.md" >&2
exit 1
