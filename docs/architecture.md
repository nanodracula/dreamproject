# DreamApp — iOS app architecture

## Organization

* Organize files by domain concept, not by type or size. Split only when concepts change for different reasons.
* Keep feature-specific code within its feature.
* Create folders and abstractions only when needed.

## Layers

* **App** owns application setup, shared dependencies, and navigation between features.
* **Features** own their UI, presentation state, business logic, and feature-specific data access.
* **Core** contains shared domain models, pure business rules, and contracts. It remains independent of UI, persistence, and external SDKs.
* **Infrastructure** implements shared persistence, networking, and platform-integration mechanisms, along with shared data implementations.
* **SharedUI** contains reusable domain-aware views used across features.
* **DesignSystem** contains generic UI components and shared visual styles, independent of app-specific domain concepts.

App assembles features and shared dependencies. Features may use shared layers but never depend on each other. Shared layers never depend on features.

## UI and business logic

* Views render state and forward user actions. They may own transient, view-local interaction state, such as focus, expanded sections, and temporary popovers.
* Keep persistence, networking, and substantial platform integration outside views.
* View models own feature presentation state, presentation logic, and operation coordination. Prefer `@Observable` for new view models.
* Separate presentation logic from business rules **by responsibility, not complexity**. Domain decisions and business policies belong in domain models, functions, or services within the feature or Core, as appropriate—not in views or view models.
* View models may call repositories directly. Do not introduce a dedicated service or additional layer merely to forward calls.
* Do not require a view model for every view. Simple components can receive data and action closures directly.

## Data access

* Keep domain models independent of storage details.
* Prefer shared domain and persistence models when their shapes align. Use separate models when the differences justify them.
* Infrastructure owns shared mechanisms such as database connections, migration execution, network transport, and storage clients.
* Feature-specific queries, mappings, and repository implementations may live within their feature, using shared Infrastructure mechanisms.
* Put genuinely shared repository implementations in Infrastructure and their shared domain contracts in Core.
* Repositories and feature-specific data access code own queries and writes. Views and business rules do not execute queries or call external SDKs directly.
* Prefer database observation for UI backed by local persistence. Treat the database as the source of truth for persisted data; avoid independently maintained writable copies. Observed snapshots, presentation state, and unsaved editing drafts are allowed.

## Dependencies and contracts

* Inject dependencies explicitly. Avoid global singletons.
* App owns shared dependencies; features assemble their own internal objects.
* Prefer initializer injection for business and data objects. SwiftUI environment injection is allowed for dependency propagation within the UI.
* Prefer concrete types. Introduce protocols when consumers benefit from interchangeable implementations or separation from external systems.
* Keep feature-local contracts and implementations within the feature when possible. Move contracts into Core or another appropriate shared layer when shared consumers or dependency direction require it.
* SharedUI components receive the data and actions they need. They must not depend on feature-specific view models or construct repositories and services internally.

## Complexity

* Prefer direct calls until an abstraction solves an actual problem.
* Start with folder boundaries. Extract modules or packages when compiler-enforced separation provides a clear benefit.
