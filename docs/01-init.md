# DreamProject repository setup plan

## Agreed layout

```text
DreamProject/
├── apps/
│   ├── ios/
│   └── web/
├── server/
│   └── supabase/
├── tools/
│   ├── bootstrap.sh             # installs mise if needed, checks prerequisites
│   ├── ci/
│   │   └── Dockerfile           # empty placeholder for a future tooling image
│   ├── run-ios.sh               # build, test, and run the iOS app
│   └── db/
├── docs/
│   └── 01 Init                  # this Markdown plan
├── .gitignore
├── mise.toml
├── AGENTS.md
├── CLAUDE.md -> AGENTS.md
└── README.md
```

Each app directory contains its platform's build configuration, sources, and
tests, making it self-contained where practical. The native iOS project lives
at `apps/ios/DreamProject.xcodeproj`, beside the `DreamProject/` source folder and
`DreamProjectTests/` test folder. Create the web directory as part of the
structure; implementation of the web app remains future work. Android is
outside the current repository scope; do not create `apps/android/`.

Use `tools/` as the single home for repository helper scripts, with iOS commands
in `tools/run-ios.sh` and database/CI helpers in `tools/db/` and `tools/ci/`.
Native platform
configuration stays with its app: Fastlane under `apps/ios/fastlane/` and web package scripts under
`apps/web/package.json` when those tools are introduced. Mise tasks invoke
`tools/run-ios.sh` with `build`, `test`, or `run` subcommands, without a separate
auto-discovered task-script directory.

Keep repository-wide configuration and command entry points at the root. Use
lowercase names for organizational directories and portable relative paths.
Do not add a root Xcode workspace for the initial setup. If shared Swift code
is needed later, place packages under a root `packages/` directory and reference
them from the iOS project by relative path.

Colocation simplifies organization and project-relative paths; it does not
isolate Xcode from the rest of the repository. External references are still
possible, so target membership and resource inclusion must be verified.

## Current repository state

- Only this plan exists, at `docs/01 Init`.
- Git has not been initialized.
- `AGENTS.md`, the `CLAUDE.md` symbolic link, and the application scaffolding
  have not been created.
- Xcode is selected at `/Applications/Xcode.app/Contents/Developer` on the
  current machine; its version and simulator availability still need checking.
- Mise is not currently available on PATH.

## Backend choice

Use Supabase Cloud. Backend setup is outside this initial repository setup.

## Tools required for initial setup

| Tool | Purpose | Setup |
| --- | --- | --- |
| Git | Repository initialization and source control | Verify the Git available through the macOS developer tools. |
| Xcode, including Swift, `xcodebuild`, `xcrun`, and `xed` | Create, build, open, and test the native iOS project | Install or select full Xcode; record the chosen version in the README. Use its bundled Swift toolchain. |
| iOS Simulator runtime | Run the app and its tests | Install a compatible runtime through Xcode and select an available simulator. |
| Bash and curl | Run bootstrap and download the mise installer | Verify the macOS-provided commands are available. |
| mise | Repository task runner and future tool version management | Install during bootstrap if missing; verify with `mise --version`. |

These are the only tools required for the initial setup. Start `mise.toml`
with the iOS task definitions described below. No separate mise-managed tool
installations are needed yet: the initial build uses Xcode's bundled tools.
Add explicit tool versions under `[tools]` when additional dependencies are
introduced. Node.js, Java, Fastlane, and Docker are not initial prerequisites.

## Implementation steps

1. **Initialize repository metadata and create the directory structure.**
   Initialize Git with an initial branch named `main`; leave commits for a
   separate step. Create an empty `AGENTS.md` and a relative symbolic link
   `CLAUDE.md -> AGENTS.md`. Keep this plan at `docs/01 Init`.
   Create `apps/ios/`, `apps/web/`, `server/supabase/`,
   `tools/ci/`, `tools/db/`, and `docs/` as shown above.
   Use `.gitkeep` files where an otherwise empty directory needs to be tracked
   by Git; remove them when real files are added.

2. **Install mise and add bootstrap tooling.**
   Implement `tools/bootstrap.sh` and document invoking it with
   `bash tools/bootstrap.sh`. The script resolves the repository root, checks
   for Bash and curl, checks whether mise is installed, and installs mise if
   needed using its official installer. Ensure the installed executable is
   available to the script without requiring shell activation, verify
   `mise --version`, and run `mise install` from the repository root.
   Make the script safe to rerun. Check Git and full Xcode availability and
   report actionable instructions for missing prerequisites. Check for an
   available iOS Simulator runtime before attempting builds or tests.
   Record the selected Xcode version and simulator runtime in the README.

   Create root `mise.toml` with `ios:build`, `ios:test`, and `ios:run` tasks,
   calling `tools/run-ios.sh`, which selects `apps/ios/` as its working directory.
   Use `xcodebuild` with the
   `DreamProject.xcodeproj` project and shared `DreamProject` scheme. Build for
   iOS Simulator and let the test task accept an explicit simulator
   destination; document how to select one available on the current machine.
   Define the commands as part of setup and verify them after the project
   exists. Leave web task definitions for its implementation.

3. **Create the native iOS project.**
   Create a real `apps/ios/DreamProject.xcodeproj` with an `DreamProject`
   application target and shared scheme. Put Swift files and assets in
   `apps/ios/DreamProject/`, using a synchronized folder assigned to the app
   target. Choose the deployment target and bundle identifier during app
   setup. Do not create an empty placeholder `.xcodeproj` directory.

4. **Configure paths and tests.**
   Let Xcode's normal project root (`SRCROOT`) resolve to `apps/ios/`.
   File-based build settings use paths such as `DreamProject/...`, relative to
   that directory. Create an `DreamProjectTests` test target with a separate
   synchronized folder at `apps/ios/DreamProjectTests/`, and include it in the
   shared scheme's test action. Keep test files out of the application target
   and include only intended app resources. Resolve repository-wide script
   paths explicitly from the iOS project directory when invoking them from
   Xcode.

5. **Add a root `.gitignore`.**
   Ignore macOS metadata, Xcode user-specific state, DerivedData, build output,
   and local environment files and secrets. Keep shared Xcode schemes, project
   configuration, dependency lockfiles, and example environment files tracked.
   Check representative paths with `git check-ignore` to confirm generated
   files are excluded without hiding source files or shared configuration.

6. **Add the empty CI Dockerfile and repository documentation.**
   Create `tools/ci/Dockerfile` and leave it empty. Docker image definition and
   builds are later work; the empty placeholder is not a buildable image.

   Write a root `README.md` with the repository layout, declared tools,
   prerequisites, bootstrap command, and implemented mise commands. Document
   `xed apps/ios` as the Xcode opening command from the repository root;
   opening `apps/ios/DreamProject.xcodeproj` directly also works.
   Document the distinction between app configuration and repository helpers
   in `tools/`, with task definitions in `mise.toml`.
   A root npm package is not required.

7. **Verify the setup.**
   From the repository root, open `xed apps/ios` and verify the shared scheme
   is available through
   `xcodebuild -list -project apps/ios/DreamProject.xcodeproj`.
   Build for an available iOS Simulator and run the test target through the
   mise tasks. Confirm project references use portable paths, test files have
   the correct target membership, and unrelated platform files are excluded
   from app build inputs. Check bootstrap shell syntax and verify bootstrap
   works both with mise present and when installation is needed in a suitable
   test environment. Confirm `mise.toml` contains the documented tasks and
   `tools/ci/Dockerfile` remains empty. Inspect Git status for unintended
   generated or secret files.

## Current scope

This update changes only the Markdown plan at `docs/01 Init`. All repository
initialization, directory creation, iOS scaffolding, `.gitignore`, bootstrap
tooling, mise installation and configuration, the empty CI Dockerfile, and
README creation remain planned. Web app implementation, shared
packages, and Docker image definitions will be added when needed.
