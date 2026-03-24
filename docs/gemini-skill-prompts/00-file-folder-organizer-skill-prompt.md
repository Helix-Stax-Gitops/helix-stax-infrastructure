# File & Folder Organizer Skill — Gemini Deep Research Prompt

> **Model**: Gemini 2.5 Pro (Deep Research mode)
> **Usage**: Paste everything below the --- line into Gemini Deep Research
> **Output**: A production-ready SKILL.md for Claude Code

---

## Your Role

You are an expert in file system organization, developer tooling, and AI agent skill design. You are creating a comprehensive SKILL.md file for Claude Code — Anthropic's CLI-based AI coding assistant. Claude Code uses "skills" (structured prompt files at ~/.claude/skills/{skill-name}/SKILL.md) to give it domain-specific methodologies.

Your job is to research best practices for file and folder organization across multiple contexts (personal files, project repos, monorepos, knowledge bases) and produce a single, production-ready SKILL.md that Claude Code can use to organize ANY directory structure a user points it at.

Use your Deep Research capabilities to search for: file organization methodologies, digital decluttering best practices, monorepo patterns (Nx, Turborepo, Google, Meta), knowledge management structures (PARA, Johnny Decimal, Obsidian vault patterns), Windows/macOS/Linux file system conventions, and safe file operations patterns.

---

## What is a Claude Code Skill?

A SKILL.md is a structured markdown file that lives in `~/.claude/skills/{skill-name}/SKILL.md`. When a user triggers the skill (via slash command or automatic detection), Claude Code loads the file and follows its methodology.

**Skill file structure:**
```markdown
---
description: One-line description used for skill matching/discovery
triggers:
  - keyword or phrase that activates this skill
  - another trigger phrase
---

# Skill Name

## Description
What this skill does and when to use it.

## Process
Step-by-step methodology Claude follows.

## Guidelines
Rules, constraints, and best practices.

## Examples
Concrete examples showing the skill in action.
```

**Key constraints:**
- Claude Code runs in a terminal (CLI) — no GUI, no drag-and-drop
- It has access to: Bash, Read, Write, Edit, Glob, Grep tools
- On Windows 11 with bash shell (Git Bash) — must use Unix paths and commands
- The user must approve destructive operations (deletes, moves)
- Skills should be methodology-focused, not just a list of commands

## Reference Skill: ComposioHQ File Organizer

Here's an existing file organizer skill to use as a starting point. It's good but limited — it only handles personal file cleanup (Downloads folders, duplicates). I need something much more comprehensive.

**What it does well:**
- 7-step process: Clarify → Analyze → Pattern Recognition → Duplicate Detection → Plan → Execute → Summary
- Safety-first: always confirms before deleting, logs all moves
- Preserves timestamps, handles filename conflicts

**What it's missing:**
- No monorepo/project structure awareness
- No knowledge base (Obsidian, Notion export) organization
- No git-awareness (doesn't check .gitignore, doesn't preserve git history)
- No config file reference updating (CLAUDE.md, settings.json, imports)
- No decision framework for "archive vs delete vs restructure"
- No duplicate-purpose directory detection (e.g., three infra/ folders)
- No awareness of AI agent ecosystems (MCP servers, skill files, agent configs)
- No compliance/audit trail for file operations

## What I Need: The Complete File & Folder Organizer

Create a SKILL.md that handles ALL of these scenarios:

### Scenario 1: Personal File Cleanup
- Messy Downloads folder (500+ files, mixed types)
- Desktop clutter
- Duplicate photos/videos across drives
- Old installer files, temp files, cache
- Scattered documents with no naming convention

### Scenario 2: Project Repository Organization
- Single-project repos with poor structure
- Files in wrong directories, stale branches
- Test files mixed with source, no clear src/test/docs separation
- Missing README, LICENSE, .gitignore
- Config files scattered at root

### Scenario 3: Monorepo Restructuring
- Multiple sub-projects in one repo with unclear boundaries
- Duplicate-purpose directories (three different infra/ folders)
- Stale/legacy directories mixed with active code
- Empty placeholder directories
- Shared code vs project-specific code boundary confusion
- Reference files (CLAUDE.md, settings.json, CI configs) that break when paths change

### Scenario 4: Knowledge Base / Vault Organization
- Obsidian vault with inconsistent folder structure
- Templates in multiple locations (duplicates)
- Orphaned notes (no backlinks)
- Inconsistent naming conventions
- Missing index/MOC (Map of Content) files

### Scenario 5: Multi-Drive / Cross-Location Organization
- Files spread across C:\, D:\, Google Drive, external drives
- Need to consolidate or establish clear location rules
- "Where does this go?" decision framework

### Scenario 6: Archive & Offload
- Identifying what should be archived vs deleted vs kept active
- Moving to cold storage (Google Drive, external drive, S3/R2)
- Maintaining a manifest of what was archived and where

## Research Topics

Research ALL of the following and incorporate findings into the skill:

### 1. File Organization Methodologies
- **PARA Method** (Projects, Areas, Resources, Archives) by Tiago Forte
- **Johnny Decimal** system (structured numbering)
- **GTD Filing** (Getting Things Done)
- **Noguchi Filing** system
- **LATCH** (Location, Alphabet, Time, Category, Hierarchy)
- **Marie Kondo / KonMari** digital adaptation
- Which methodology works best for which scenario?

### 2. Developer/Project Organization
- Google's monorepo structure patterns
- Nx and Turborepo workspace conventions
- Standard project layouts by language (Python src/, JS packages/, Go cmd/)
- The "Screaming Architecture" pattern
- Fractal/feature-based folder structure vs layer-based
- Where tests, docs, configs, scripts, CI should live

### 3. Duplicate Detection Strategies
- Content-based (MD5, SHA256) for exact duplicates
- Fuzzy matching for near-duplicates (similar filenames, same size different name)
- Handling intentional duplicates (backups, versioned copies)
- Size-first scanning for efficiency

### 4. Safe File Operations
- Undo/rollback patterns (move log, trash instead of delete)
- Preserving file metadata (timestamps, permissions)
- Handling filename conflicts on move
- Atomic operations (don't leave half-moved state)
- Git-aware moves (git mv vs plain mv)
- Symlink handling

### 5. Reference Updating
- When files move, what references break? (imports, configs, paths in docs)
- Grep-based reference scanning before moves
- Obsidian wikilink updating
- CLAUDE.md and settings.json path updating
- CI/CD config path updating

### 6. Decision Frameworks
- "Archive vs Delete vs Keep" decision tree
- "Monorepo vs Multi-repo vs Hybrid" for project splitting
- "Flat vs Nested" depth guidelines (when is 3 levels deep too much?)
- "Convention vs Configuration" — when to enforce naming vs let it be organic
- Age-based rules (files untouched for 6+ months → archive candidate)

### 7. Windows-Specific Considerations
- Long path limitations (260 chars, or extended paths)
- Case-insensitivity gotchas
- Junction points and symlinks
- OneDrive/Google Drive sync conflicts
- PowerShell vs Git Bash path differences
- Hidden files and system files to never touch

### 8. AI Agent Ecosystem Organization
- Where MCP server code should live
- Agent config/skill file organization
- Prompt template organization
- Dataset and training data organization
- Log file management

## Output Requirements

Produce a COMPLETE, PRODUCTION-READY SKILL.md file with:

### 1. Frontmatter
- Description that enables skill discovery
- Trigger phrases covering all scenarios

### 2. Description Section
- What the skill does
- When to use it (all 6 scenarios)
- What it does NOT do (set expectations)

### 3. Process Section (Step-by-Step)
The process should be a unified methodology that adapts to the scenario. Something like:

**Step 1: Scope & Intent**
- What directory/directories are we organizing?
- What's the goal? (cleanup, restructure, archive, deduplicate, standardize)
- What's off-limits? (files to never touch, directories to skip)
- What's the scenario? (personal, project, monorepo, vault, multi-drive, archive)

**Step 2: Survey & Analyze**
- Map current structure (tree view, size analysis, file type distribution)
- Identify patterns (naming conventions, groupings, date ranges)
- Detect problems (duplicates, empty dirs, stale files, misplaced items, duplicate-purpose dirs)
- Check for git repos, .gitignore, CLAUDE.md, CI configs that reference paths

**Step 3: Classify & Decide**
- For each problem found, apply decision framework
- Categorize files/dirs: keep-in-place, move, rename, archive, delete, merge
- For monorepos: identify boundaries, overlaps, canonical locations
- Flag items needing user decision (can't auto-decide)

**Step 4: Plan & Present**
- Generate before/after structure comparison
- List every move/rename/delete with reasoning
- Identify references that will break and how to fix them
- Estimate disk space savings
- Present plan to user for approval — NEVER execute without approval

**Step 5: Execute**
- Execute approved operations in safe order (create dirs first, then move, then delete)
- Log every operation for undo capability
- Use git mv when inside git repos
- Update references (grep + sed/edit) after moves
- Handle conflicts gracefully

**Step 6: Verify & Report**
- Verify new structure matches plan
- Confirm no broken references (grep for old paths)
- Generate summary: what changed, what was archived, what needs manual action
- Provide maintenance tips specific to the organized structure

### 4. Guidelines Section
- Safety rules (never delete without confirmation, always log moves)
- Git awareness rules
- Platform-specific rules (Windows paths, case sensitivity)
- Naming conventions to suggest (kebab-case, YYYY-MM-DD dates, etc.)
- Size thresholds (when to flag large files, when to suggest compression)
- Depth guidelines (when nesting is too deep)

### 5. Templates Section
Provide reusable templates for:
- Standard project structure (by language/framework)
- Monorepo structure
- Obsidian vault structure
- Archive manifest format
- Move log format

### 6. Examples Section
Provide 3-4 concrete examples:
- Cleaning a 500-file Downloads folder
- Restructuring a messy monorepo with duplicate directories
- Organizing an Obsidian vault with scattered templates
- Archiving old projects to external storage

## Quality Checklist

Before finalizing, verify the skill:
- [ ] Handles all 6 scenarios listed above
- [ ] Has clear user approval gates (never auto-deletes)
- [ ] Is git-aware (uses git mv, checks .gitignore, preserves history)
- [ ] Handles Windows paths correctly
- [ ] Includes undo/rollback capability
- [ ] Updates references after moves
- [ ] Provides decision frameworks, not just commands
- [ ] Is concise enough to fit in Claude Code's context (aim for 300-500 lines)
- [ ] Follows the SKILL.md frontmatter format exactly
- [ ] Includes trigger phrases that would naturally match user requests like "organize my files", "clean up this repo", "restructure this project", "deduplicate my folders"
