# private-skills

> Bulk-manage all your private git-backed Claude Code skills from a single command. No hardcoded lists — auto-discovers every skill with a `.git/` directory.

If you maintain multiple private skills in `~/.claude/skills/` and are tired of `cd`-ing into each one to pull, commit, and push, this skill gives you **one command** to manage them all.

## Prerequisites

- [ ] **Git** installed and configured (`git --version`)
- [ ] **GitHub CLI** installed and authenticated (`gh auth status`)
- [ ] **Claude Code** with skills support (`npx skills --help`)
- [ ] At least one git-backed skill in your `~/.claude/skills/` directory

## Install

```bash
npx skills add EFFYLYX/private-skills
```

Verify it's installed:

```bash
ls ~/.claude/skills/private-skills/SKILL.md
```

## Usage

Use natural language in Claude Code:

- **"list my private skills"** — shows all git-backed skills with remote URL, clean/dirty status, and last commit
- **"show skill status"** — detailed `git status` per skill (branch, ahead/behind, changed files)
- **"push all skills"** — commit and push all dirty skills in one go
- **"pull english-coach"** — pull latest for a specific skill
- **"publish my-new-skill"** — initialize git and create a private GitHub repo for a plain skill directory

Or use the slash command directly:

```
/private-skills list
/private-skills status
/private-skills push [skill_name]
/private-skills pull [skill_name]
/private-skills publish <skill_name>
```

## How It Works

The script scans the parent `skills/` directory for subdirectories containing `.git/`. It skips symlinked directories (those are managed externally). Path resolution is portable — derived from the script's own location, so it works whether `.claude` is in `~` or in a project directory.

## Commands

| Command | Description |
|---------|-------------|
| `list` | Show all git-backed skills: name, remote URL, clean/dirty, last commit |
| `status` | Detailed git status per skill (branch, ahead/behind, changed files) |
| `push [name]` | `git add -A && commit && push` for one or all dirty skills |
| `pull [name]` | `git pull --rebase` for one or all skills |
| `publish <name>` | `git init` + `gh repo create EFFYLYX/<name> --private` for a new skill |

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `"No git-backed skills found"` | Make sure your skills are cloned repos (have `.git/` dir), not just plain directories. Run `ls ~/.claude/skills/*/. git` to check. |
| `"gh: command not found"` | Install GitHub CLI: `winget install GitHub.cli` (Windows) or `brew install gh` (macOS), then `gh auth login`. |
| Push fails with auth error | Run `gh auth status` to verify you're logged in. If using HTTPS, ensure your token has `repo` scope. |
| `"skill 'X' not found"` | Check the exact directory name in `~/.claude/skills/`. The name is case-sensitive. |
| Symlinked skills not showing | By design — symlinked skills (e.g. from `~/.agents/skills/`) are managed externally and skipped. |

## License

MIT
