<p align="center">
  <h1 align="center">🔍 LogLens</h1>
  <p align="center">
    <strong>A modern log viewer for Posit Connect</strong>
    <br />
    Browse, filter, and search job logs from your Posit Connect server — all from a beautiful R Shiny interface.
  </p>
  <p align="center">
    <a href="#-quick-start">Quick Start</a> ·
    <a href="#-features">Features</a> ·
    <a href="#-project-structure">Project Structure</a> ·
    <a href="#-development">Development</a>
  </p>
</p>

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔗 **Auto-Connect** | Connects to Posit Connect on startup via environment variables — no manual setup inside the app |
| 📦 **Content & Job Browser** | Lists all deployed content and their associated jobs in a searchable sidebar |
| 🏷️ **Log Classification** | Automatically classifies every line into `ERROR`, `WARN`, `INFO`, `DEBUG`, `TRACE`, `STDOUT`, or `STDERR` |
| 🎛️ **Interactive Filters** | Toggle log levels on/off with colour-coded filter chips |
| 🔎 **Full-Text Search** | Instantly search across all log messages with a free-text input |
| 📊 **Summary Counters** | At-a-glance severity breakdown with colour-coded count badges |
| 🌗 **Dark / Light Theme** | One-click toggle with preference saved to `localStorage` |
| 📋 **Paginated Table** | High-performance `reactable` table with customisable page sizes (50 / 100 / 250 / 500) |

## 🏗️ Tech Stack

- **[Rhino](https://appsilon.github.io/rhino/)** — enterprise-grade R Shiny framework
- **[bslib](https://rstudio.github.io/bslib/) (Bootstrap 5)** — theming and layout
- **[reactable](https://glin.github.io/reactable/)** — interactive data tables
- **[connectapi](https://pkgs.rstudio.com/connectapi/)** — Posit Connect API client
- **Sass (via Node)** — premium design system with CSS custom properties
- **Cypress** — end-to-end testing
- **GitHub Actions** — CI pipeline for linting, building, and testing

## 📋 Prerequisites

| Dependency | Version |
|---|---|
| **R** | ≥ 4.1 |
| **renv** | (bundled) |
| **Node.js** | ≥ 20 |
| **npm** | ≥ 9 |

You also need a running **Posit Connect** server and a valid API key.

## 🚀 Quick Start

### 1. Clone & Install R Dependencies

```bash
git clone <your-repo-url> LogLens
cd LogLens
Rscript -e "renv::restore()"
```

### 2. Install Node Dependencies

```bash
cd .rhino
npm ci
cd ..
```

### 3. Configure Environment Variables

Create a `.Renviron` file in the project root (it's git-ignored):

```env
CONNECT_SERVER=https://your-connect-server.example.com
CONNECT_API_KEY=your-api-key
```

### 4. Build Frontend Assets

```bash
Rscript -e "rhino::build_js(); rhino::build_sass()"
```

### 5. Launch the App

```bash
Rscript -e "rhino::app()"
```

The app will open in your browser. Select a content item and job from the sidebar, then click **Fetch Logs**.

## 🗂️ Project Structure

```
LogLens/
├── app/
│   ├── main.R                  # Root UI & server — wires sidebar + log viewer
│   ├── js/
│   │   └── index.js            # Theme toggle (dark/light with localStorage)
│   ├── logic/
│   │   ├── connect_api.R       # Posit Connect API wrapper (connectapi)
│   │   └── log_parser.R        # Log parsing & severity classification
│   ├── styles/
│   │   └── main.scss           # Full design system (light + dark themes)
│   ├── static/                 # Static assets
│   └── view/
│       ├── sidebar.R           # Content/job selectors, connection status
│       └── log_viewer.R        # Filters, search, summary boxes, log table
├── tests/
│   ├── testthat/               # R unit tests
│   └── cypress/                # End-to-end tests
├── .github/
│   └── workflows/
│       └── rhino-test.yml      # CI: lint → build → test
├── config.yml                  # Rhino app configuration
├── dependencies.R              # Explicit package declarations for deployment
├── renv.lock                   # Reproducible R dependency lockfile
├── rhino.yml                   # Rhino framework config (sass: node)
└── app.R                       # Entry point (calls rhino::app())
```

## 🛠️ Development

### Run the App (Dev Mode)

Start the app on port 3333 (used by Cypress):

```bash
cd .rhino && npm run run-app
```

### Lint

```bash
# All linters
Rscript -e "rhino::lint_r(); rhino::lint_js(); rhino::lint_sass()"
```

### Unit Tests

```bash
Rscript -e "rhino::test_r()"
```

### End-to-End Tests (Cypress)

```bash
cd .rhino && npm run test-e2e
```

### CI Pipeline

The GitHub Actions workflow (`.github/workflows/rhino-test.yml`) runs automatically on pushes to `main` and on pull requests:

1. **Lint** — R, JavaScript, and Sass
2. **Build** — JavaScript and Sass compilation
3. **Test** — R unit tests + Cypress E2E

## 🧩 Architecture

```
┌──────────────────────────────────────────────────────┐
│                      Browser                         │
│  ┌────────────┐  ┌─────────────────────────────────┐ │
│  │  Sidebar   │  │         Log Viewer              │ │
│  │            │  │                                 │ │
│  │ • Content  │  │ • Summary counters              │ │
│  │   picker   │  │ • Level filter chips            │ │
│  │ • Job      │  │ • Free-text search              │ │
│  │   picker   │  │ • Paginated log table           │ │
│  │ • Fetch    │  │                                 │ │
│  └─────┬──────┘  └──────────┬──────────────────────┘ │
│        │                    │                        │
└────────┼────────────────────┼────────────────────────┘
         │                    │
    ┌────▼────────────────────▼────┐
    │         Server (R)          │
    │                             │
    │  connect_api.R  log_parser  │
    │       │              │      │
    └───────┼──────────────┼──────┘
            │              │
    ┌───────▼──────┐  Parse & classify
    │ Posit Connect│  severity levels
    │   REST API   │
    └──────────────┘
```

## 📝 Environment Variables

| Variable | Required | Description |
|---|---|---|
| `CONNECT_SERVER` | ✅ | Full URL of your Posit Connect server |
| `CONNECT_API_KEY` | ✅ | API key with permissions to read content and logs |
| `RHINO_LOG_LEVEL` | ❌ | App-level logging threshold (default: `INFO`) |
| `RHINO_LOG_FILE` | ❌ | Path to write app logs to a file (default: console only) |

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes and ensure linters + tests pass
4. Commit (`git commit -m "feat: add my feature"`)
5. Push to your branch and open a Pull Request

---

<p align="center">
  Built with ❤️ using <a href="https://appsilon.github.io/rhino/">Rhino</a> by <a href="https://appsilon.com/">Appsilon</a>
</p>
