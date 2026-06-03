# Debugging guidelines

- **Reproduce first.** Get a reliable repro before attempting a fix; without one
  you can't confirm the fix works.
- **Find the root cause.** Trace the actual cause rather than patching the
  symptom; don't paper over a bug with a workaround.
- **Form and test hypotheses.** Investigate with evidence (logs, prints, a
  debugger, bisection) instead of guessing or changing things at random.
- **Change one thing at a time.** Make isolated changes so you know which one
  mattered; revert experiments that didn't help.
- **Verify the fix and check for siblings.** Confirm the repro is gone, watch for
  regressions, and look for the same bug pattern elsewhere.
- **Clean up.** Remove temporary debug prints, logging, and scaffolding once the
  issue is resolved.
