# Project: [NAME]

## Overview

Brief description of what this project does.

## Tech Stack

| Layer     | Technology |
|-----------|-----------|
| Language  |           |
| Framework |           |
| Database  |           |
| Build     |           |
| Deploy    |           |

## Setup Instructions

```bash
# Clone
git clone <repo-url>
cd <project-name>

# Install dependencies
npm install  # or pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your values

# Run
npm start  # or python3 main.py
```

## Architecture

```
project-root/
├── src/            # Source code
│   ├── routes/     # API routes / pages
│   ├── models/     # Data models
│   ├── services/   # Business logic
│   └── utils/      # Shared utilities
├── tests/          # Test files
├── docs/           # Documentation
├── config/         # Configuration files
└── scripts/        # Build / deploy scripts
```

## Key Files

| File | Purpose |
|------|---------|
| `src/index.ts` | Entry point |
| `package.json` | Dependencies and scripts |
| `.env` | Environment variables |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET    | /    | Health check |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PORT`   | No       | Server port (default: 3000) |

## Development Notes

- Branch strategy: feature branches → PR → main
- Commit convention: `type: description` (feat, fix, docs, refactor, test)
- Run tests before pushing: `npm test`

## Status: Planning

> **Next Steps:**
> - [ ] Initialize project structure
> - [ ] Set up development environment
> - [ ] Implement core features
> - [ ] Write tests
> - [ ] Deploy
