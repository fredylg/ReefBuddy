# ReefBuddy

A high-contrast, New Brutalist iOS app for saltwater aquarium hobbyists, powered by Cloudflare Workers and AI.

## 🚨 Critical: Xcode Project Protection

This project includes multiple layers of protection against Xcode crashes caused by UUID collisions and project file corruption:

### 🛡️ Automatic Protection
- **`.cursorrules`** - Cursor-specific project rules loaded automatically
- **`setup-hooks.sh`** - Enables git pre-commit validation
- **`verify-xcode-project.sh`** - Manual project integrity verification

### 🔧 Setup Protection
```bash
# Enable automatic validation on every commit
./setup-hooks.sh

# Manual verification (run before/after any iOS changes)
./verify-xcode-project.sh
```

### ⚠️ Critical Rules
- **NEVER** delete or recreate `iOS/ReefBuddy.xcodeproj/project.pbxproj`
- **ALWAYS** check for UUID collisions: `grep "8A1B2C3D000000" iOS/ReefBuddy.xcodeproj/project.pbxproj | sort | uniq -d`
- **ONLY EDIT** the existing project file when adding/removing Swift files

## 🏗️ Architecture

- **Frontend:** SwiftUI with New Brutalist design system
- **Backend:** Cloudflare Workers (TypeScript/ES Modules)
- **Database:** Cloudflare D1 (SQLite)
- **AI:** Claude 3.5 Sonnet via Cloudflare AI Gateway
- **Auth:** Session-based with KV storage

## 🚀 Quick Start

### Backend Development
```bash
# Install dependencies
npm install

# Start local development server
npx wrangler dev

# Apply database migrations
npx wrangler d1 migrations apply reef-db --local

# Run tests
npx vitest run
```

### iOS Development
```bash
# Verify project integrity
./verify-xcode-project.sh

# Open project (requires Xcode 15+)
open iOS/ReefBuddy.xcodeproj
```

## 📋 Project Status

See [`PLAN.md`](PLAN.md) for detailed development roadmap and current status.

## 📚 Documentation

- [`CLAUDE.md`](CLAUDE.md) - Development standards and agent roles
- [`PLAN.md`](PLAN.md) - Project roadmap and QA status
- [`iOS/README.md`](iOS/README.md) - iOS-specific setup and guidelines
- [`migrations/`](migrations/) - Database schema changes

## 🎨 Design System

**New Brutalist Manifesto:**
- Pure white backgrounds (#FFFFFF)
- Pure black text (#000000)
- Electric Aquamarine actions (#00FFD1)
- Safety Orange warnings (#FF3D00)
- Sharp 0px radius corners
- 3pt solid black borders
- Hard offset shadows (no blur)

## 🔒 Security

- Session-based authentication with KV storage
- Device-based credit tracking (3 free analyses, then IAP)
- Input validation with Zod schemas
- AI Gateway for LLM call caching
- Apple receipt validation for purchases

## 💰 Pricing Model (In-App Purchase)

- **Free:** 3 analyses per device (lifetime)
- **5 Credits:** $0.99 (com.reefbuddy.credits5)
- **50 Credits:** $4.99 - Best value, 50% savings (com.reefbuddy.credits50)

## 🚀 Deployment

```bash
# Deploy backend
npx wrangler deploy

# Apply production migrations
npx wrangler d1 migrations apply reef-db --remote
```

## 🤝 Contributing

This project uses specialized AI agents for different roles:
- **@ui-brutalist**: Frontend/SwiftUI development
- **@edge-engineer**: Backend/Cloudflare Workers
- **@data-steward**: Database migrations and integrity
- **@tester-agent**: QA and automated testing

Always run `./verify-xcode-project.sh` before and after iOS work.