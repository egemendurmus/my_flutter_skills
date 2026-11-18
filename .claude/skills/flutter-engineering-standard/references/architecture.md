# Architecture decisions

## Greenfield feature layout

```text
lib/
  app/                 # app bootstrap, router, theme
  core/                # shared HTTP client, errors, cross-cutting utilities
  features/
    devices/
      data/             # DTOs, data sources, repository implementation
      domain/           # entities, repository contract and use cases if warranted
      presentation/     # screens, widgets, immutable state, Riverpod notifier
```

Do not create empty folders or boilerplate interfaces merely to satisfy the diagram. Dependencies point inward: presentation -> domain; data implements domain contracts. A simple feature may use presentation + data directly when domain abstraction has no value. Prefer constructor/provider injection and small classes. Keep Flutter UI imports out of domain/data where possible. Keep SDK, native plugin and network access behind testable adapters.

## Greenfield defaults

Riverpod 3; Dio with timeouts and interceptors that never log secrets; go_router; Freezed/json_serializable where immutable unions or JSON parsing justify code generation. Respect the actual project Flutter/Dart SDK and lockfile. Avoid gratuitous package additions.

## Existing projects

Map current modules and dependencies first. Keep working Cubit, Provider or other patterns when change does not require migration. Refactor at boundaries using a strangler approach; do not mix two state systems within the same feature without a documented migration step.
