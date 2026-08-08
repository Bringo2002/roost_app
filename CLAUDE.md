# CLAUDE.md — `roost_app` Engineering Constitution

This file is binding operating instructions for any AI coding agent working in this repository. Read it in full at the start of every session. Every directive below is a rule, not a suggestion.

---

## 1. Scope of This Repository

This repository (`roost_app`) owns **Layer 3 — Client/Frontend** of the Roost platform. It is a Flutter application targeting Android and iOS, written in Dart.

The sibling repository `Roost` owns Layers 1 and 2: the PostgreSQL database, migrations, Spring Boot services, and REST controllers. That repository has its own `CLAUDE.md` and is **entirely out of scope** for any agent session here.

**Never open, reference, import, or attempt to edit Java, Kotlin, or Spring files — they do not exist in this repository.**

### Dependency on the Backend Contract

This repository depends on exactly one artifact from the `Roost` backend: the **DTO/JSON response contracts** exposed by its REST controllers. The Dart data models in `lib/models/` must mirror those contracts field-for-field.

- When a backend PR description flags a breaking response-shape change, update the corresponding Dart model(s) in lockstep.
- **Never silently patch around a contract drift** with defensive parsing (null coalescing, fallback defaults, or `try/catch` around deserialization). If a field is missing or renamed, that is a contract break — surface it, do not mask it.
- If a requested change requires an API contract change in the sibling backend repository rather than being solvable client-side alone, **stop and flag this explicitly** instead of attempting a client-only workaround.

---

## 2. Context Isolation & Stacked PR Workflow (Layer 3 Only)

### Layer 3 Definition

Layer 3 in this repository comprises:

| Concern | Directories |
|---|---|
| Dart data models (request/response DTOs mirroring backend contract) | `lib/models/` |
| API client code | `lib/services/api_service.dart` |
| Service layer (auth, chat, push, encryption, etc.) | `lib/services/` |
| UI pages (screens) | `lib/pages/` |
| Reusable widgets | `lib/widgets/` |
| Theme & styling | `lib/theme/` |
| Utilities | `lib/utils/` |
| Constants & configuration | `lib/constants/`, `lib/config.dart` |
| App entry point | `lib/main.dart` |
| Tests | `test/` |
| Platform shells | `android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/` |
| Assets | `assets/` |
| Project config | `pubspec.yaml`, `analysis_options.yaml` |

### Permitted & Out-of-Scope Boundaries

- **Read and write**: Any file listed in the table above, plus root config files (`pubspec.yaml`, `analysis_options.yaml`, `firebase.json`, `devtools_options.yaml`).
- **Out of scope — never touch in this repo**: Java, Kotlin, Spring, SQL migration files. They do not exist here.
- **Intra-repo boundary rule**: An agent working on a widget in `lib/pages/` or `lib/widgets/` must **not** simultaneously rewrite the API client (`lib/services/api_service.dart`) or data models (`lib/models/`) unless the task description explicitly spans those layers. Scope creep across internal layers causes unreviewed side effects.

### Backend API Dependency Tracking

The dependency on the `Roost` backend API is tracked as follows:

- Every Layer 3 PR description must state which backend API version or commit hash it was built and tested against.
- If a Layer 3 branch requires a backend endpoint or response shape that does not yet exist on `Roost/main`, the PR description must link to the upstream backend PR and note "**Blocked: requires Roost PR #___**."
- Never build a Layer 3 branch against an API shape that does not yet exist on the backend's `main` branch or an explicitly linked in-flight backend PR.

### Branch Topology

```
Roost (backend repo)                    roost_app (this repo)
========================                ========================

main                                    main
  │                                       │
  └─ feat/x-layer2-api ──(API contract)──►├─ feat/x-layer3-client
                                          │
                                          └─ feat/y-layer3-client
```

**Branch naming scheme for this repo:**

```
feat/<feature-name>-layer3-client
fix/<bug-name>-layer3-client
refactor/<scope>-layer3-client
```

The `layer3-client` suffix makes the stacked relationship explicit in PR titles. This repo's tooling manages only its own branches — never the upstream `Roost` repository's branches.

### 3. Git Tooling for Stacked Branches

Use **Graphite's `gt` CLI** for managing stacked PRs against GitHub.

```bash
# Initialize Graphite in the repo (run once)
gt repo init

# Create the first branch in a stack
gt branch create feat/x-layer3-client

# Add a subsequent branch on top of the current stack
gt branch create feat/x-layer3-client-part2

# Sync the stack after an upstream change (rebase all branches)
gt stack restack

# Submit the entire stack as linked PRs to GitHub
gt stack submit
```

> <VERIFY: Confirm `gt repo init`, `gt branch create`, `gt stack restack`, and `gt stack submit` match the current Graphite CLI version installed in this environment. Graphite may have renamed or restructured subcommands since the CLI's last major release.>

---

## 4. System Command Reference — Flutter

All commands assume the working directory is the repository root.

### Run (Development)

```bash
# Start on a connected device / emulator with hot reload enabled
flutter run

# Hot reload (in running session): press 'r' in terminal
# Hot restart (full restart, resets state): press 'R' in terminal

# Run on a specific device
flutter run -d <DEVICE_ID>
```

### Build Release Artifacts

```bash
# Android App Bundle (Play Store upload)
flutter build appbundle --release

# Android APK (direct install / sideloading)
flutter build apk --release

# iOS (requires macOS + Xcode + valid signing)
flutter build ios --release
```

### Testing

```bash
# Run the full test suite
flutter test

# Run widget tests only (all files in test/)
flutter test test/

# Run a specific test file
flutter test test/widget_test.dart

# Run integration tests (if integration_test/ directory exists)
flutter test integration_test/
```

### Static Analysis & Formatting

```bash
# Static analysis — must pass with zero issues before any PR
flutter analyze

# Check formatting (does not modify files)
dart format --output=show --set-exit-if-changed .

# Apply formatting
dart format .
```

### Dependency Management

```bash
# Check for outdated or vulnerable dependencies
flutter pub outdated

# Get dependencies after pubspec.yaml changes
flutter pub get

# Upgrade dependencies to latest compatible versions
flutter pub upgrade
```

---

## 5. Engineering Standards at 20M+ Scale — Frontend

### API Payload Size Budget

| Response class | Maximum payload | Rule |
|---|---|---|
| List views (property feed, search results, chat list) | ≤ 50 KB per page of results | Only include fields needed for the card/preview. Do not fetch detail-level fields in list endpoints. |
| Detail views (property detail, user profile) | ≤ 15 KB per response | Acceptable to include all fields. Images are URLs, not inline data. |
| Chat messages (single page) | ≤ 30 KB per page | Paginate. Never fetch full conversation history in a single request. |

When adding a new field to a response model in `lib/models/`, justify its payload cost in the PR description. If the field is only needed on a detail view, do not add it to the list-view model variant.

### `const` Constructors

- Use `const` constructors on every widget, value object, and data class that permits them.
- When touching any widget subtree, check every constructor in that subtree for missing `const` and add it where valid.
- Mark widget parameters as `final` and constructors as `const` by default. Only remove `const` when there is a concrete reason (mutable state, non-const default values).

### Widget Rebuild Minimization

This codebase uses `StatefulWidget` + `setState` for state management. Apply these rules strictly:

- **Scope `setState` narrowly.** Never call `setState` on a parent widget when only a child's subtree needs to rebuild. Extract the changing subtree into its own `StatefulWidget`.
- **Use `const` child widgets** wherever possible to allow the framework to short-circuit rebuild of unchanged subtrees.
- Inside `ListView.builder`, never create closures or objects that force every item to rebuild on parent state changes. Keep `itemBuilder` callbacks lightweight; extract list items into `const`-constructable `StatelessWidget` subclasses when they take only immutable data.
- Do not introduce a new state management framework (BLoC, Riverpod, Provider, etc.) without explicit task-level approval. If a task description does not mention state management migration, use the existing `StatefulWidget` + `setState` pattern.
- When `setState` scope is insufficient for a specific performance-critical case, extract state into an `InheritedWidget`, `ValueNotifier` + `ValueListenableBuilder`, or `ChangeNotifier` + `ListenableBuilder` — scoped to the minimum subtree required.

### Frame Budget

- **Target: 60 fps minimum** (16.67 ms per frame) on all supported devices.
- **Target: 120 fps** on devices with high-refresh displays (ProMotion, 120 Hz Android panels) — verify with `flutter run --profile` and the Flutter DevTools performance overlay.
- Profile command:

```bash
flutter run --profile
```

Open Flutter DevTools → Performance tab → enable "Track Widget Builds" to identify unnecessary rebuilds.

### Image Handling

- **Always use `CachedNetworkImage`** (already a dependency: `cached_network_image`) for all network images. Never use `Image.network()` directly.
- Request resized/thumbnailed image URLs from the CDN for list views. Do not load full-resolution images into `ListView` items.
- Set explicit `width`, `height`, or `fit` on every image widget to prevent layout jumps and unbounded memory allocation.
- Provide a `placeholder` and `errorWidget` for every `CachedNetworkImage` instance.

### Offline / Error / Empty State Rule

Every network call in the widget tree must render three distinct states:

1. **Loading** — a shimmer placeholder or `CircularProgressIndicator`, never a blank screen.
2. **Error** — a user-readable message with a retry action. Never swallow errors silently (no empty `catch (_) {}`). At minimum, show a `SnackBar` or inline error widget.
3. **Empty** — a purposeful empty-state illustration or message ("No results found"), never an invisible empty `Container` or `SizedBox.shrink()`.

Audit every `try/catch` block you write or touch: if the `catch` body is empty or only contains a `// TODO`, replace it with proper error handling immediately.

---

## 6. Testing Standards — Frontend

### TDD Is Mandatory

Do not write implementation code without a preceding failing test. The cycle is: **Red → Green → Refactor.**

### Minimum Coverage Requirements

| Layer | Required tests |
|---|---|
| Data models (`lib/models/`) | Unit tests for `fromJson` and `toJson` — roundtrip every model against the exact JSON shape from the backend contract. Include edge cases: null optional fields, missing keys, type coercion (e.g. `num` to `int`). |
| Services (`lib/services/`) | Unit tests for business logic. Mock `http.Client` for API service tests. Test error paths (401, 500, timeout, `SocketException`). |
| Pages & Widgets (`lib/pages/`, `lib/widgets/`) | Widget tests for any new or modified widget with non-trivial interaction logic (taps, form input, conditional rendering). Use `WidgetTester`. |

### Test File Placement

- Place test files in `test/` mirroring the `lib/` directory structure:
  - `lib/models/property.dart` → `test/models/property_test.dart`
  - `lib/services/api_service.dart` → `test/services/api_service_test.dart`
  - `lib/pages/search/search_page.dart` → `test/pages/search/search_page_test.dart`

### Running Tests Before Committing

Run the full suite and static analysis before every commit:

```bash
flutter test && flutter analyze
```

Both must pass with zero failures and zero analysis issues.

---

## 7. AI Behavioral Policy

### Code Output Rules

When producing code for this repository:

- No introductory pleasantries, no apologies, no meta-commentary about what you are about to do.
- Output direct, fully-typed, production-ready file diffs or new files only.
- Every Dart file must pass `flutter analyze` with zero issues.
- Every new public API must include a doc comment (`///`).
- Never output pseudocode, partial implementations, or `// TODO: implement` stubs without immediately following them with the real implementation.

### When to Stop and Ask

This behavioral policy governs code-output format specifically. It does **not** suppress the agent's judgment about:

- **Asking a clarifying question** when a task is genuinely ambiguous (e.g. unclear which model a new field belongs to, or which page a new widget should appear on).
- **Flagging a backend dependency** when a requested change actually requires an API contract change in the sibling `Roost` repository rather than being solvable client-side alone. State this clearly: "This change requires a backend contract update in `Roost`. It cannot be completed in `roost_app` alone."
- **Refusing scope creep** when a task targets one internal layer but would require cascading changes across unrelated layers not mentioned in the task.
