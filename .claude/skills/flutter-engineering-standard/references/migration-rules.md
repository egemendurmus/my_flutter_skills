# Adaptive migration rules

1. Inventory routes, persistence formats, external contracts, device protocols, permissions, startup/background behavior and current tests.
2. Write behavioral invariants and capture a baseline (tests or reproducible manual checks). Mark unverified invariants clearly.
3. Rank risks by severity, likelihood and blast radius. Prioritize credentials, data loss, connection leaks and crash paths.
4. Refactor one feature or boundary at a time; preserve public API and data shape until a deliberate migration is approved.
5. Introduce adapters around legacy IO, then extract immutable state and domain rules where justified. Avoid wholesale framework swaps.
6. Test before and after; provide rollback instructions and flag migrations needing staging hardware.
7. Never auto-commit, push, open PRs, or execute production-changing commands without explicit user authorization.
