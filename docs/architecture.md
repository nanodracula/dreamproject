# iOS app architecture

## Organization

- Organize files by domain concept, not by type or size. Split only when concepts change for different reasons.
- Keep feature-specific code within its feature.
- Create folders and abstractions only when needed.

## Layers

- **App** owns application setup, shared dependencies, and navigation between features.
- **Features** own their UI, presentation state, business logic, and feature-specific data access.
- **Core** contains shared domain models, pure business rules, and contracts. It remains independent of UI, persistence, and external SDKs.
- **Infrastructure** implements persistence, networking, and platform integrations etc.
- **SharedUI** contains reusable domain views.
- **DesignSystem** contains generic UI components and shared visual styles.

App assembles features and shared dependencies. Features may use shared layers but never depend on each other. Shared layers never depend on features.

## UI and business logic

- Views render state and forward user actions. Keep persistence, networking, and substantial platform integration outside views.
- View models own presentation state and coordinate operations through repositories and services.
- Add a business logic service only when it owns meaningful rules. Avoid pass-through layers.
- Keep blocking I/O and heavy processing off the main thread.

## Data access

- Keep domain models independent of storage details. Persistence behavior belongs in Infrastructure.
- Prefer shared domain and persistence models when their shapes align. Use separate models when the differences justify them.
- Repositories and feature-specific data access code own queries and writes.
- Prefer database observation for UI backed by local persistence. Avoid maintaining a second source of truth.

## Dependencies and contracts

- Inject dependencies explicitly. Avoid global singletons.
- App owns shared dependencies; features assemble their own internal objects.
- Prefer concrete types. Introduce protocols when consumers benefit from interchangeable implementations or separation from external systems.
- Keep feature-local contracts within the feature. Put contracts needed across layers in a shared layer that preserves dependency direction.

## Complexity

- Prefer direct calls until an abstraction solves an actual problem.
- Start with folder boundaries. Extract modules or packages when compiler-enforced separation provides a clear benefit.
