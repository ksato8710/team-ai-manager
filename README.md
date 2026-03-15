# Team AI Manager

Design organization management tool built as a native macOS app with AI-powered insights and project charter generation.

## Features

### Organization Management
- **Members** - Team roster with grade hierarchy (IC / Lead / Principal / Executive), status tracking, capacity management
- **Projects** - Project lifecycle management with 6 service types (Business Design, UX, Growth, Brand, HR Development) and phase tracking
- **Clients** - Client relationship management with industry classification and status tracking

### Growth
- **Skills** - 4-category skill taxonomy (Design, Tech, Business, Research) with 1-5 proficiency levels
- **Skills Matrix** - Cross-tabulated member-skill proficiency visualization
- **Knowledge** - Organization knowledge base (case studies, processes, guidelines, templates)

### Intelligence
- **AI Insights** - Workload analysis, skill gap detection, staffing recommendations
- **Scanners** - Configurable data source integrations (Figma, GitHub, Slack, Jira, Notion, etc.)

### Tools
- **Project Planning** - AI-facilitated project charter creation via side-by-side chat + document UI. Supports voice input (Japanese). Generates structured 13-section project charters through multi-turn dialogue. Supports **Claude Code CLI** and **OpenAI Codex CLI** as AI backends (switchable in Settings).

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Swift 5.9+**
- **AI CLI** (at least one) - Required for the Project Planning tool's AI features:
  - [Claude Code CLI](https://claude.ai/download) - Anthropic's CLI (subscription auth)
  - [OpenAI Codex CLI](https://github.com/openai/codex) - OpenAI's CLI

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/ksato8710/team-ai-manager.git
cd team-ai-manager
```

### 2. Prepare organization data

The app seeds its database from JSON files on first launch. Sample data is provided in `Data/organization.sample/`.

**To use sample data** (3 members, 2 projects - good for testing):

No action needed. The app falls back to `Data/organization.sample/` automatically.

**To use your own data:**

```bash
cp -r Data/organization.sample Data/organization
```

Edit the JSON files in `Data/organization/` to match your team:

| File | Description |
|---|---|
| `roles.json` | Job titles and departments |
| `skills.json` | Skill definitions with 1-5 level descriptions |
| `clients.json` | Client names, industries, relationship status |
| `members.json` | Team members with roles, grades, specializations |
| `projects.json` | Projects with service types, phases, dates |
| `assignments.json` | Project-member and member-skill assignments |
| `knowledge.json` | Knowledge base articles |
| `insights.json` | Initial AI insight entries |

`Data/organization/` is gitignored to keep your real team data private.

### 3. Build and run

```bash
# Build the app bundle
./build-app.sh

# Launch the app
open .build/TeamAIManager.app
```

Or run directly without the `.app` bundle:

```bash
swift build
.build/debug/TeamAIManager
```

### 4. (Optional) AI CLI setup

The Project Planning tool requires an AI CLI for charter creation. Install at least one:

**Claude Code CLI:**
```bash
# Install and sign in with your Anthropic subscription
# See: https://claude.ai/download
```

**OpenAI Codex CLI:**
```bash
npm install -g @openai/codex
```

The app automatically detects installed CLIs by searching common paths (`~/.local/bin/`, `/usr/local/bin/`, etc.) and `PATH`. You can switch between backends in **Settings > AI**.

## Data Storage

All data is stored locally in a SQLite database:

```
~/Library/Application Support/TeamAIManager/team_ai_manager.sqlite
```

No data is sent to remote servers. The only external call is from the Project Planning tool to the locally installed AI CLI (Claude Code or Codex).

## Architecture

```
Sources/
├── App/                    # App entry point, state management
├── Database/               # GRDB migrations, seed data loader
├── Models/                 # GRDB record types (11 models)
├── Services/
│   ├── AI/                 # AI analysis + Claude CLI integration
│   ├── Scanner/            # Data source scanner framework
│   └── SpeechRecognizer.swift
└── Views/
    ├── Dashboard/          # Overview stats and insights
    ├── Members/            # Team member management
    ├── Projects/           # Project lifecycle
    ├── Clients/            # Client relationship
    ├── Skills/             # Skill taxonomy + matrix
    ├── Knowledge/          # Knowledge base
    ├── AIInsights/         # AI-generated insights
    ├── Settings/           # Scanner configuration
    ├── Tools/              # Project Planning (+ placeholders)
    ├── Doc/                # In-app documentation
    └── Shared/             # Reusable components
```

**Tech Stack:**
- SwiftUI (macOS native)
- GRDB.swift (SQLite ORM)
- Claude Code CLI / OpenAI Codex CLI (AI features, selectable)
- Speech framework (voice input)

## License

MIT
