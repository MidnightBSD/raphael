# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Raphael is a lightweight GTK web browser forked from Midori, targeting WebKitGTK. It is written primarily in **Vala** (which compiles to C via the Vala compiler) and uses CMake as its build system.

## Build Commands

```bash
# Configure and build
mkdir _build
cd _build
cmake -DCMAKE_INSTALL_PREFIX=/usr ..
make

# Install (after build)
sudo make install

# Run without installing (from repo root)
./_build/raphael [URL]

# Run tests (requires X11 display)
cd _build && xvfb-run make check

# Ninja backend (faster, if installed)
cmake -G Ninja ..
ninja
```

## Testing

Tests live in `tests/` and use the GLib Test framework. The main test binary is `tests/database.vala`.

```bash
# Run all tests
cd _build && xvfb-run ctest

# Run specific test binary directly
cd _build && ./tests/database
```

Validation shell scripts in `tests/`:
- `license.sh` — validates source file licenses (requires `licensecheck`)
- `desktop.sh` — validates `.desktop` file (requires `desktop-file-validate`)
- `potfiles.sh` — validates translation file list

## Architecture

### Core Components (`core/`)

All major components are `GObject`-based Vala classes:

- **`App`** (`app.vala`) — `Gtk.Application` subclass. Entry point; registers custom URI schemes (`internal://`, `favicon://`, `stock://`, `res://`), loads extensions via Libpeas.
- **`Browser`** (`browser.vala`) — `Gtk.ApplicationWindow` subclass. Manages the tab bar, navigation controls, status bar, and fullscreen/zoom state. Holds a list of open and recently-closed tabs.
- **`Tab`** (`tab.vala`) — `WebKit.WebView` subclass. Represents a single web page. Handles TLS certificates, loading progress, pinned/colored tab state, and deferred loading for pinned tabs.
- **`Urlbar`** (`urlbar.vala`) — URL/search input with autocomplete from history and bookmarks.
- **`Database`** (`database.vala`) — SQLite wrapper for history, bookmarks, and session data. Uses async operations.
- **`Settings`** (`settings.vala`) — Manages user preferences (JavaScript, cookies, plugins, privacy). Binds to `WebKit.Settings`.

### Plugin System (`extensions/`)

Extensions use [Libpeas](https://wiki.gnome.org/Projects/Libpeas) and implement one or more activatable interfaces:
- `AppActivatable` — activated once when the app starts
- `BrowserActivatable` — activated per browser window
- `TabActivatable` — activated per tab

Built-in extensions: `adblock`, `bookmarks`, `session`, `colorful-tabs`, `status-clock`, `web-extensions`.

### Web Extension Support (`web/`, `extensions/web-extensions.vala`)

Implements a manifest.json-compatible browser extension format supporting background scripts, content scripts, browser actions, and a `browser.*` JavaScript API.

### UI Definitions (`ui/`)

GTK UI template files (`.ui`) are compiled into a GResource bundle and embedded in the binary. CSS theming is in `data/gtk3.css` and `data/about.css`.

### Localization (`po/`)

Uses intltool/gettext. To update translations, use standard `intltool-update` tooling after running cmake.

## Code Style

From the project's contributing guidelines:
- 4-space indentation, no tabs
- 80–120 column width
- `snake_case` for variables
- Space between keywords/functions and parentheses: `if (condition)`
- Prefer `new Gtk.Widget()` over `using Gtk; new Widget()`
- Omit `Raphael` and `GLib` namespace prefixes within the codebase
- No explicit `private` specifiers (default visibility is private in Vala)
- Cuddled else/catch: `} else {` and `} catch (Error error) {`

## Key Dependencies

- **Vala** compiler (valac)
- **CMake** 3.2+
- **GTK+** 3.12+
- **WebKitGTK** 2.16.6+ (`webkit2gtk-4.0`)
- **libsoup** 2.48+
- **SQLite** 3.6.19+
- **Libpeas** (plugin system)
- **GCR** 2.32+ (certificate handling)
- **JSON-Glib** 0.12+
- **libarchive**
- **intltool** (for localization)
