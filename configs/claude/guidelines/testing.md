# Testing guidelines

- **Match the project's test setup.** Use the existing framework, structure, and
  naming; don't introduce a new test tool when one is already in use.
- **Run the tests.** Run the relevant tests after changes and before calling
  work done; report failures with their output rather than hiding them.
- **Test behavior, not internals.** Assert on observable outputs/effects, not
  private implementation details that make tests brittle.
- **Cover the edges.** Include failure paths and boundary cases, not just the
  happy path.
- **Keep tests deterministic.** No dependence on wall-clock time, network,
  ordering, or shared mutable state; avoid flakiness.
- **Never fake a pass.** Don't weaken, skip, or delete a test to make it green —
  fix the underlying cause.
