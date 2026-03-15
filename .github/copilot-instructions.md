# Copilot Instructions

## Shields.io Badges

Always integrate shields.io badges when creating or updating documentation (README, setup guides, FAQs, etc.).

### Top-level badges (README.md, after the H1 heading)

Add two rows of badges immediately below the main title:

**Row 1 — Project identity (static):**
- License badge (link to LICENSE file)
- Primary tech/platform badges with logos (e.g., Azure, AWS, GitHub Actions, Node.js — whatever the project uses)
- PRs Welcome badge (link to repo pulls page)

**Row 2 — Repo stats (dynamic):**
- GitHub Stars (`?style=social`, link to stargazers)
- GitHub Forks (`?style=social`, link to network/members)
- GitHub Issues (link to issues page)
- Last Commit (link to commits/main)
- Repo Size

### Section-specific badges

Add contextual badges at the top of major doc sections to signal the tools, languages, or concepts involved. Examples:
- Azure CLI / GitHub CLI badges near prerequisite or CLI-heavy sections
- Shell Script / Bash badges near script execution sections
- OIDC / Security badges near authentication or security sections
- Language/framework badges near code-specific sections

### Badge formatting rules

- Use shields.io `logo=` parameter for recognizable icons
- Stars/forks badges use `?style=social`; all others use default flat style
- Clickable badges should link to the relevant page (GitHub issues, pulls, stargazers, LICENSE, etc.)
- Static tech badges use appropriate brand colors (e.g., Azure `#0078D4`, GitHub `#181717`, Bash `#4EAA25`)
- Place badges on their own line(s) with a blank line before and after
