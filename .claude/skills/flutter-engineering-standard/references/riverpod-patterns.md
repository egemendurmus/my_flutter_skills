# Riverpod patterns

- Use Riverpod 3 providers/notifiers with separate immutable state objects; do not make `Notifier<Foo>` return `this` as state or mutate a list then assign the same instance.
- Represent async data with `AsyncValue` or an explicit sealed state as appropriate; keep user-visible error and retry behavior.
- Use `ref.watch` for reactive dependencies, `ref.read` for event handlers, and `ref.onDispose` for resources; account for asynchronous cancellation and widget unmounting.
- Inject repository and IO adapters through providers, not global mutable static fields.
- Test notifier transitions via `ProviderContainer` and provider overrides; include success, error, retry and disposal scenarios.
- If an existing feature uses Cubit/BLoC, preserve it unless migration is specifically in scope.
