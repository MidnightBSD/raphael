# Repository Guidelines

## Project Structure & Module Organization

- `core/`: main Vala codebase (GObject classes like `App`, `Browser`, `Tab`, `Urlbar`, `Database`).
- `extensions/`: Libpeas plugins (`*.plugin.in`, `*.vala`) such as adblock, session, web-extensions.
- `ui/`: GTK Builder templates (`*.ui`) compiled into a GResource bundle (`gresource.xml`).
- `data/`: desktop/appdata templates, CSS (`gtk3.css`, `about.css`), HTML/JS assets.
- `web/`: web-extension runtime support.
- `tests/`: GLib Test unit tests (`*.vala`) plus validation scripts (`*.sh`).
- `po/`: gettext/intltool localization files.
- `_build/`: out-of-tree build output (do not edit by hand; avoid committing artifacts).

## Build, Test, and Development Commands

```sh
mkdir -p _build && cd _build
cmake -DCMAKE_INSTALL_PREFIX=/usr ..
make            # or: cmake -G Ninja .. && ninja
./raphael https://example.com
```

- Install: `cd _build && sudo make install`
- Run tests (headless): `cd _build && xvfb-run make check`
- Run with verbose failures: `cd _build && CTEST_OUTPUT_ON_FAILURE=1 ctest`
- Run a single test: `cd _build && ctest -R urlbar` (or execute `./tests/urlbar`)

## Coding Style & Naming Conventions

- Indentation: 4 spaces, no tabs; keep lines ~80–120 columns.
- Vala: `snake_case` for variables; `UpperCamelCase` for types.
- Spacing: `if (condition)` / `foreach (item in items)`; cuddled `} else {` / `} catch (Error e) {`.
- Prefer unprefixed namespaces inside the project (omit `Raphael.` / `GLib.` unless needed).

## Testing Guidelines

- Tests use the GLib Test framework and are discovered from `tests/*.vala` by CMake.
- Add new unit tests as a new `tests/<name>.vala` file; the binary/test name matches the filename.
- Keep tests deterministic and runnable under `xvfb-run` in CI.

## Portability Targets

- Changes must work on MidnightBSD; prefer solutions that stay portable to other BSDs and Linux.
- Avoid OS-specific paths/assumptions; gate platform differences in CMake where needed and document any new dependencies in `README.md`.

## Commit & Pull Request Guidelines

- Commits are typically short, imperative subjects (e.g., “Fix …”, “Add …”, “Update …”), optionally with a scope (`[Android] …`) or issue/PR reference (`(#123)`).
- PRs should include: problem statement, approach, test command(s) run, and screenshots for UI changes (`ui/`, `data/*.css`).
- Update `CHANGELOG.md` for user-visible changes and keep security-sensitive fixes clearly described.
