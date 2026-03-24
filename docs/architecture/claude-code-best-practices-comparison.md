# Claude Code Best Practices Comparison: shanraisshan/claude-code-best-practice vs Helix Stax

**Author**: Cass Whitfield (stax-architect)
**Date**: 2026-03-20
**Source Repo**: [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice)

---

## 1. Executive Summary

The `shanraisshan/claude-code-best-practice` repo is a comprehensive reference implementation covering Claude Code's configuration surface area: skills, subagents, hooks, commands, settings, memory, MCP servers, and cross-model workflows. It catalogs **60+ settings**, **22 hook events**, **15 agent frontmatter fields**, **11 skill/command frontmatter fields**, and **63 built-in commands**.

Our Helix Stax setup is significantly more sophisticated in orchestration (PACT framework, 23 agents, 70+ skills, 40+ hook scripts, VSM-based governance). However, we are **under-utilizing** several Claude Code platform features that the best-practice repo documents. Key gaps: no `.claude/rules/` directory, no project-level commands, no progressive disclosure in skills (reference.md/examples.md), no cross-model workflow, missing agent frontmatter fields (effort, isolation, background, maxTurns), no hooks config separation (config.json + config.local.json pattern), and bloated global CLAUDE.md via `@`-referenced protocol files.

**Bottom line**: Our architecture is more ambitious but less aligned with platform conventions. Adopting best-practice patterns would make our setup more maintainable, more portable, and take better advantage of Claude Code's built-in features.

---

## 2. Pattern-by-Pattern Comparison

### 2.1 CLAUDE.md Structure and Length

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Line count** | Recommends <200 lines per file | Global: 126 lines, Project: 81 lines (both good), BUT 10 `@`-referenced protocol files inject ~1,500+ lines at load time | GAP |
| **Content** | Repo overview, key components, critical patterns, workflow tips, debugging tips | Mission statement, governance tables, delegation rules, orchestration patterns | DIFFERENT |
| **Hierarchy** | Single CLAUDE.md per scope (global, project, component) with lazy-loading descendants | Global CLAUDE.md + Project CLAUDE.md + `@` references to `~/.claude/protocols/` | GAP |
| **200-line limit** | Explicit guidance: "Keep CLAUDE.md under 200 lines per file for reliable adherence" | Files are under 200 individually, but `@` references expand them far beyond that | GAP |

**Gap Analysis**: Our CLAUDE.md files are individually concise, but the `@`-reference mechanism to `protocols/` injects massive amounts of text into context. The best-practice repo recommends keeping the total loaded context compact. We have ~30 protocol files in `~/.claude/protocols/` -- even if loaded on demand, they're all referenced from CLAUDE.md and could be auto-loaded.

**Recommendation**: **ADAPT**
- Move operational protocols out of `@`-references and into `.claude/rules/` (auto-loaded contextually) or `.claude/skills/` (loaded on invocation)
- Keep CLAUDE.md as a concise project manifest (<200 lines including Working Memory)
- Use descendant CLAUDE.md files for sub-project specifics

---

### 2.2 Settings Cascade (Global vs Project vs Local)

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Hierarchy** | 5-tier: Managed > CLI > local > project > global | 3-tier used: local, project, global | OK |
| **Global settings** | Permissions + MCP servers + hooks + UI customization (spinners, attribution, statusline, env vars) | Permissions + MCP servers only | GAP |
| **Project settings** | Team-shared in `.claude/settings.json` (committed) | Only `.claude/settings.local.json` at project level (git-ignored) | GAP |
| **Local overrides** | `.claude/settings.local.json` (git-ignored) for personal per-project | Used for ClickUp MCP permissions | OK |
| **Environment vars** | `"env"` field in settings.json (e.g., `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`) | Not used | GAP |
| **Deny rules** | Explicit deny list for dangerous bash commands (rm, chmod, docker, kill) | No deny rules at all | GAP |
| **Ask rules** | Granular ask rules for package managers, git, docker, curl | No ask rules (everything is `allow: Bash(*)`) | GAP |
| **Attribution** | Custom commit and PR attribution in settings | Not configured (handled manually per MEMORY.md) | GAP |
| **Auto-compact** | `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: 80` via env | Not configured | GAP |

**Gap Analysis**: Our global `settings.json` is permissive -- `Bash(*)` allows everything without prompting. The best-practice repo uses a thoughtful tiered approach: allow safe tools broadly, ask for confirmation on destructive commands (`rm`, `docker`, `kill`, `git`), and deny nothing (relying on ask as a guard). We also miss `env` field for important environment variables and have no project-level `settings.json` for team-shared config.

**Recommendation**: **ADOPT** (High Priority)
- Add ask rules for destructive commands to global settings
- Set `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` via env field
- Add `attribution` field for commit authorship
- Create `.claude/settings.json` (committed) at project level for team settings

---

### 2.3 Skills Organization (Progressive Disclosure)

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Structure** | `SKILL.md` + `reference.md` + `examples.md` in skill dir | `SKILL.md` + sometimes `references/` dir, sometimes `scripts/` dir | PARTIAL |
| **Progressive disclosure** | SKILL.md is concise instructions; reference.md has specs; examples.md has I/O pairs | Most skills are monolithic SKILL.md with everything inlined | GAP |
| **Frontmatter fields used** | name, description, argument-hint, disable-model-invocation, user-invocable, allowed-tools, model, effort, context, agent, hooks | name, description (inconsistent use of others) | GAP |
| **Skill count** | ~3 demo skills | 70+ skills (global) | STRENGTH |
| **Agent skill pattern** | `user-invocable: false` for skills meant only for agent preloading | Not used -- all skills appear in `/` menu | GAP |
| **Monorepo discovery** | Nested `.claude/skills/` in subdirectories for lazy loading | All skills at global level (`~/.claude/skills/`) | GAP |
| **Char budget** | Aware of 15,000 char limit for skill descriptions; recommends concise descriptions | No awareness or optimization | GAP |

**Gap Analysis**: We have an impressive 70+ skills but they lack the progressive disclosure pattern. The best-practice repo demonstrates separating a skill into: (1) SKILL.md with concise task instructions, (2) reference.md with detailed specs/templates, and (3) examples.md with input/output pairs. This keeps context lean while providing depth when needed. We also don't use `user-invocable: false` for agent-only skills, meaning all 70+ skills pollute the `/` menu and consume character budget.

**Recommendation**: **ADOPT** (Medium Priority)
- Restructure top ~10 most-used skills with reference.md/examples.md
- Add `user-invocable: false` to agent-preloaded skills (pact-*, n8n-*, etc.)
- Move project-specific skills to project-level `.claude/skills/`
- Audit skill descriptions for brevity (char budget awareness)

---

### 2.4 Agent Definitions and Agent Memory

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Location** | `.claude/agents/*.md` (project) or `~/.claude/agents/*.md` (global) | `.claude/agents/*.md` (project-level only, under HelixStax/) | OK |
| **Frontmatter fields** | 15 fields: name, description, tools, disallowedTools, model, permissionMode, maxTurns, skills, mcpServers, hooks, memory, background, effort, isolation, color | 5-7 fields: name, description, color, permissionMode, model, memory, skills | GAP |
| **Agent count** | ~3 demo agents | 23 production agents | STRENGTH |
| **Memory scopes** | `user`, `project`, `local` (3 scopes) | `user` only (all agents use `memory: user`) | GAP |
| **Agent-memory dirs** | Per-agent dirs with MEMORY.md + topic files | Per-agent dirs exist (`~/.claude/agent-memory/stax-*/`) | OK |
| **maxTurns** | Explicit turn limits to prevent runaway agents | Not set on any agent | GAP |
| **background** | `background: true` for always-background agents | Not used | GAP |
| **isolation** | `isolation: worktree` for git worktree isolation | Not used (worktree managed by hooks instead) | NEUTRAL |
| **effort** | Per-agent effort level override | Not used | GAP |
| **disallowedTools** | Deny specific tools per agent | Not used | GAP |
| **Agent hooks** | Per-agent hooks in frontmatter (6 supported hooks) | Not used | GAP |
| **mcpServers** | Per-agent MCP server scoping | Not used | GAP |
| **PROACTIVELY** | Description keyword for auto-invocation | Not used | GAP |

**Gap Analysis**: Our agents use only ~5 of 15 available frontmatter fields. Critical missing fields: `maxTurns` (prevents runaway context exhaustion), `background: true` (for agents like vigil-monitor that should always run in background), `disallowedTools` (for tighter agent sandboxing), `effort` (to match our L1/L2/L3 model routing), and per-agent `hooks` (could replace some of our global hook logic). Agent memory is all `user`-scoped; some agents (especially project-specific ones) would benefit from `project` scope to share learned patterns across team members.

**Recommendation**: **ADOPT** (High Priority)
- Add `maxTurns` to all agents (5-15 depending on complexity)
- Add `background: true` to stax-vigil-monitor
- Add `effort` to agents matching our L1/L2/L3 routing (haiku for L1, sonnet for L2, opus for L3 -- these map to `low`/`medium`/`high`)
- Add `disallowedTools` to restrict coders from spawning sub-agents
- Consider `project` memory scope for stax-architect and stax-devops-engineer

---

### 2.5 Commands vs Skills

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Commands** | `.claude/commands/*.md` -- entry points for workflows; frontmatter identical to skills | `~/.claude/commands/` -- 9 PACT workflow commands | PARTIAL |
| **Skills** | `.claude/skills/*/SKILL.md` -- domain knowledge, reusable capabilities | `~/.claude/skills/` -- 70+ skills for domain knowledge | OK |
| **Distinction** | Commands = user-facing workflow entry points; Skills = domain knowledge (often preloaded into agents) | Commands = PACT workflows; Skills = domain expertise | ALIGNED |
| **Command location** | Both global and project-level | Global only | GAP |
| **Pattern** | Command -> Agent -> Skill (orchestration architecture) | Command -> orchestrator -> Task -> agent (PACT architecture) | DIFFERENT |
| **Frontmatter in commands** | Full frontmatter support (model, effort, context: fork, agent, hooks) | Likely plain markdown without frontmatter | GAP |

**Gap Analysis**: Our commands are PACT-specific workflow triggers (orchestrate, comPACT, rePACT, etc.). This is fine architecturally, but we miss the "Command -> Agent -> Skill" pattern that the best-practice repo demonstrates. More importantly, we have no project-level commands -- all commands are global. Project-specific workflows (e.g., a deploy command for helix-stax-infrastructure) should live at project level.

**Recommendation**: **ADAPT** (Low Priority)
- Consider adding project-level commands for project-specific workflows
- Add YAML frontmatter to existing commands (model, effort, context fields)
- The Command -> Agent -> Skill pattern is already achieved by our PACT cycle; no need to change

---

### 2.6 Rules (Modular Rules Directory)

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Location** | `.claude/rules/*.md` (project) or `~/.claude/rules/*.md` (global) | No rules directory at either level | GAP |
| **Purpose** | Modular, always-loaded guidelines that complement CLAUDE.md | Guidelines embedded in CLAUDE.md and protocols/ | GAP |
| **Example** | `markdown-docs.md` -- documentation formatting standards | No equivalent | GAP |
| **vs CLAUDE.md** | Rules are always loaded (like CLAUDE.md) but modular | Everything in CLAUDE.md or `@`-referenced protocols | GAP |

**Gap Analysis**: Claude Code's `.claude/rules/` directory is a first-class feature for modular, always-loaded instructions. This is exactly what many of our `protocols/` files should be. Rules are automatically loaded without needing `@` references, and they can be organized by topic (e.g., `coding-standards.md`, `security-rules.md`, `git-conventions.md`). This is a cleaner pattern than our `@~/.claude/protocols/` approach.

**Recommendation**: **ADOPT** (High Priority)
- Create `~/.claude/rules/` with extracted content from key protocols:
  - `delegation.md` (from pact-delegation-rules.md)
  - `security.md` (from S5 non-negotiables)
  - `git-conventions.md` (commit standards, branch naming)
  - `coding-standards.md` (from pact-principles.md CODE section)
- Keep complex, reference-heavy protocols as skills (loaded on demand) rather than rules (always loaded)
- Rules should be concise (<100 lines each) -- they're always in context

---

### 2.7 Hooks Architecture

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Hook events** | 22 events documented, all wired to single `hooks.py` dispatcher | 40+ individual hook scripts, each for a specific purpose | DIFFERENT |
| **Architecture** | Single dispatcher script (`hooks.py`) + config files | Multiple independent Python scripts per hook | DIFFERENT |
| **Config separation** | `hooks-config.json` (team) + `hooks-config.local.json` (personal, git-ignored) | `hooks.json` (single config file) | GAP |
| **Disable mechanism** | `disableAllHooks` in settings.local.json + per-hook toggles in config | No disable mechanism documented | GAP |
| **Sound notifications** | Audio feedback via TTS-generated wav files per event | No sound notifications | SKIP |
| **Hook types** | 4 types: command, prompt, agent, http | command type only | GAP |
| **Async hooks** | Explicit `async: true` for non-blocking hooks | Some hooks use async | PARTIAL |
| **once option** | `once: true` for session-level hooks | Not used systematically | GAP |
| **Matchers** | Regex matchers for tool-specific hooks | String matchers (e.g., `"matcher": "Bash"`) | OK |
| **Agent hooks** | Per-agent hooks via frontmatter | Not used | GAP |
| **Hook dedup** | Platform deduplicates identical hooks | Not relevant (different scripts) | N/A |
| **Environment vars** | `$CLAUDE_PROJECT_DIR`, `$CLAUDE_ENV_FILE`, `$CLAUDE_SKILL_DIR` | `$CLAUDE_PLUGIN_ROOT` used | OK |

**Gap Analysis**: Our hooks system is more functionally rich (40+ scripts covering phase gates, memory management, credential rotation, worktree management, etc.) but architecturally different from the best-practice pattern. They use a single dispatcher with config-based toggling; we use individual scripts. Both approaches work, but we lack the **config separation** pattern (`hooks-config.json` + `hooks-config.local.json`) that enables per-developer hook customization. We also don't use `prompt` or `agent` hook types, which could replace some of our Python validation scripts with inline Claude reasoning.

**Recommendation**: **ADAPT** (Medium Priority)
- Add a `hooks-config.json` + `hooks-config.local.json` pattern for per-hook toggles
- Consider `prompt` type hooks for validation that requires judgment (e.g., commit message quality)
- Add `once: true` to session-level hooks (session_init, compaction_refresh)
- Keep our multi-script architecture -- it's better for our complexity level
- Consider `agent` type hooks for complex validation (e.g., security scanning)

---

### 2.8 Cross-Model Workflows (Claude + External Models)

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Pattern** | Claude (Plan) -> Codex/GPT (QA Review) -> Claude (Implement) -> Codex (Verify) | Claude only (PACT framework) | GAP |
| **Workflow** | 4-step: Plan -> QA Review -> Implement -> Verify | 5-phase: Prepare -> Architect -> Code -> Test -> Review | DIFFERENT |
| **Cross-validation** | Different model reviews plan against codebase, inserts intermediate phases | Same model family for all phases | GAP |
| **Terminal setup** | Dual terminals (Claude + Codex) | Single terminal with agent teams | DIFFERENT |

**Gap Analysis**: The cross-model workflow uses a second AI model (GPT/Codex) as an independent reviewer -- the idea being that different models catch different issues. Our PACT framework uses multiple Claude agents, which provides diversity of perspective but not diversity of model architecture.

**Recommendation**: **SKIP** (for now)
- Our Gemini skill prompts (this repo's `docs/gemini-skill-prompts/`) already suggest cross-model thinking
- The value proposition is real but the operational complexity is high
- Revisit when Helix Stax has more mature CI/CD where automated cross-model checks could run

---

### 2.9 Agent Teams Patterns

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Setup** | iTerm2 + tmux + `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` | Agent Teams via PACT dispatch protocol | OK |
| **Pattern** | Spawn parallel teammates with shared task list | TaskCreate + TaskUpdate + Task(name, team_name, subagent_type) | ALIGNED |
| **Coordination** | Shared task list for coordination | Tasks + SendMessage for coordination | STRENGTH |
| **Task sharing** | `CLAUDE_CODE_TASK_LIST_ID` env var for cross-session | Used implicitly via PACT dispatch | OK |
| **Worktrees** | Agent `isolation: worktree` frontmatter field | Managed via hook scripts (worktree_auto.py, worktree_guard.py) | DIFFERENT |

**Gap Analysis**: Our Agent Teams implementation is more mature than the best-practice repo's demo. We have structured dispatch, task tracking, signal handling, and team coordination. The main gap is using the platform's native `isolation: worktree` field instead of our custom worktree hooks.

**Recommendation**: **ADOPT** (Low Priority)
- Test `isolation: worktree` agent frontmatter as a potential replacement for worktree hooks
- Set `CLAUDE_CODE_TASK_LIST_ID` explicitly in settings.json env for deterministic task persistence

---

### 2.10 Memory Management

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Auto-memory** | Platform-managed MEMORY.md per project per user | Used (200-line limit acknowledged) | OK |
| **Agent memory** | `memory: user/project/local` frontmatter + per-agent MEMORY.md (200-line first load) | `memory: user` on all agents + pact-memory SQLite skill | STRENGTH |
| **200-line limit** | First 200 lines of MEMORY.md injected at startup; agent curates into topic files | Handled via memory_trim.py hook | OK |
| **Three-layer model** | Auto-memory + Agent memory (two layers) | Auto-memory + pact-memory (SQLite) + Agent memory (three layers) | STRENGTH |
| **Memory search** | Read/grep MEMORY.md files | FTS5 + vector search via pact-memory skill | STRENGTH |
| **Compaction recovery** | TaskList + TaskGet to reconstruct state | Same pattern documented in pact-context-economy.md | ALIGNED |

**Gap Analysis**: Our memory system is more sophisticated (SQLite with FTS5, vector search, migrations, entity graphs). The best-practice repo uses simpler file-based memory. Our main gap is not leveraging `project` and `local` memory scopes for agents -- everything is `user` scope, meaning agent knowledge is never shared with team members and is always cross-project.

**Recommendation**: **ADAPT** (Low Priority)
- Use `project` memory scope for agents whose knowledge is project-specific (stax-devops-engineer, stax-database-engineer)
- Keep `user` scope for cross-project agents (stax-architect, stax-security-engineer)
- Our three-layer model is superior; no changes needed to the architecture

---

### 2.11 MCP Server Configuration

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Recommended servers** | Context7, Playwright, Chrome DevTools, DeepWiki, Excalidraw (5 daily-use) | 14 production servers (GitHub, ClickUp, Postgres, n8n, Cloudflare, Zitadel, Grafana, etc.) | STRENGTH |
| **Project-level config** | `.mcp.json` at repo root (committed, team-shared) | No `.mcp.json` -- all servers in global `~/.claude/settings.json` | GAP |
| **Per-agent scoping** | `mcpServers` in agent frontmatter | Not used | GAP |
| **Permission rules** | `mcp__*` patterns in allow/deny/ask | Global allow all (`mcp__*` implicit via Bash(*)) | GAP |
| **Research tools** | Context7 for up-to-date docs, DeepWiki for repo understanding | Not using Context7 or DeepWiki | GAP |

**Gap Analysis**: We have a rich MCP server ecosystem but it's all globally configured. The best-practice repo recommends: (1) project-level `.mcp.json` for team-shared servers, (2) per-agent MCP scoping so agents only see relevant servers, and (3) Context7/DeepWiki for documentation retrieval. We should also add explicit MCP permission rules rather than blanket allow.

**Recommendation**: **ADOPT** (Medium Priority)
- Create `.mcp.json` at project roots for project-specific servers
- Add `mcpServers` to agent frontmatter (e.g., stax-database-engineer gets `postgres-db`; stax-devops-engineer gets `cloudflare-edge`, `grafana-obs`)
- Evaluate Context7 and DeepWiki for research phases
- Add granular MCP permission rules to settings

---

### 2.12 Monorepo Patterns

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **CLAUDE.md loading** | Ancestor (UP) at startup + Descendant (DOWN) lazy-loaded | Single project CLAUDE.md + global CLAUDE.md | PARTIAL |
| **Skills discovery** | Nested `.claude/skills/` in subdirs, auto-discovered when working in that dir | All skills at global level | GAP |
| **Component isolation** | Each package gets its own CLAUDE.md + skills + rules | No sub-project isolation | GAP |

**Gap Analysis**: Our multi-repo setup (HelixStax umbrella with sub-projects) would benefit from component-level CLAUDE.md files. For example, `helix-stax-infrastructure/CLAUDE.md` for infra conventions, `ai-agent-session-center/CLAUDE.md` for AASC-specific patterns.

**Recommendation**: **ADOPT** (Low Priority)
- Add CLAUDE.md to major sub-project directories
- Move project-specific skills to project-level `.claude/skills/`

---

### 2.13 RPI Workflow (Research-Plan-Implement)

| Aspect | Best Practice | Helix Stax | Assessment |
|--------|--------------|------------|------------|
| **Phases** | Research -> Plan -> Implement (3 phases, with GO/NO-GO gate) | Prepare -> Architect -> Code -> Test (4 phases) | SIMILAR |
| **Feature folders** | `rpi/{feature-slug}/` with REQUEST.md, research/, plan/, implement/ | `docs/preparation/`, `docs/architecture/`, `docs/plans/` (separate dirs) | DIFFERENT |
| **Specialist agents** | requirement-parser, product-manager, ux-designer, senior-software-engineer, cto-advisor | stax-preparer, stax-product-manager, stax-architect, stax-*-coder | ALIGNED |
| **GO/NO-GO gate** | Explicit viability check after research | No explicit viability gate | GAP |

**Recommendation**: **ADAPT** (Low Priority)
- Consider adding a GO/NO-GO gate after PREPARE phase
- Feature folder pattern is interesting but our docs/ structure works fine

---

## 3. Priority Improvements

### NOW (High Priority -- Immediate Value)

| # | Improvement | Effort | Impact | Files Affected |
|---|------------|--------|--------|----------------|
| 1 | **Create `~/.claude/rules/`** with extracted protocol content | Medium | High -- reduces context bloat from `@`-references | New: `~/.claude/rules/delegation.md`, `security.md`, `git-conventions.md`, `coding-standards.md` |
| 2 | **Add ask/deny rules** to global settings.json | Low | High -- prevents accidental destructive commands | `~/.claude/settings.json` |
| 3 | **Add missing agent frontmatter** (maxTurns, effort, disallowedTools, background) | Medium | High -- prevents runaway agents, enforces model routing | `HelixStax/.claude/agents/*.md` (23 files) |
| 4 | **Set environment variables** in settings (CLAUDE_AUTOCOMPACT_PCT_OVERRIDE, CLAUDE_CODE_TASK_LIST_ID) | Low | Medium -- automatic compaction + task persistence | `~/.claude/settings.json` |
| 5 | **Add attribution config** to settings | Low | Medium -- automates commit authorship | `~/.claude/settings.json` |

### NEXT (Medium Priority -- Planned Sprint)

| # | Improvement | Effort | Impact | Files Affected |
|---|------------|--------|--------|----------------|
| 6 | **Progressive disclosure for top skills** (reference.md + examples.md) | High | Medium -- leaner context, better skill quality | `~/.claude/skills/*/` (top 10 skills) |
| 7 | **Mark agent-only skills** with `user-invocable: false` | Low | Medium -- declutters `/` menu, saves char budget | `~/.claude/skills/pact-*/SKILL.md`, `n8n-*/SKILL.md` |
| 8 | **Hooks config separation** (config.json + config.local.json) | Medium | Medium -- per-developer hook customization | `~/.claude/hooks/config/` |
| 9 | **Project-level .mcp.json** | Low | Medium -- team-shared MCP config | New: `HelixStax/.mcp.json` |
| 10 | **Per-agent MCP scoping** | Medium | Medium -- agents see only relevant servers | `HelixStax/.claude/agents/*.md` |

### LATER (Low Priority -- Future Enhancement)

| # | Improvement | Effort | Impact | Files Affected |
|---|------------|--------|--------|----------------|
| 11 | **Sub-project CLAUDE.md files** | Low | Low -- better context per sub-project | New CLAUDE.md in sub-project dirs |
| 12 | **Project-level commands** | Medium | Low -- project-specific workflows | New: `HelixStax/.claude/commands/` |
| 13 | **Evaluate Context7 + DeepWiki** MCP servers | Low | Medium -- better docs retrieval in PREPARE phase |  `~/.claude/settings.json` |
| 14 | **Test `isolation: worktree`** agent field | Low | Low -- potential simplification of worktree hooks | Agent frontmatter |
| 15 | **Diversify agent memory scopes** (project, local) | Low | Low -- share agent knowledge across team | Agent frontmatter |
| 16 | **Prompt/agent hook types** | Medium | Low -- replace some Python validation with Claude reasoning | Hook config |
| 17 | **Cross-model verification** workflow | High | Medium -- architectural diversity in review | New workflow config |

---

## 4. Proposed Updated .claude/ Structure

### Global (`~/.claude/`)

```
~/.claude/
|-- CLAUDE.md                              # TRIMMED: <100 lines, mission + quick ref only
|-- settings.json                          # UPDATED: +ask/deny rules, +env, +attribution
|-- settings.local.json                    # Personal overrides
|
|-- rules/                                 # NEW: Always-loaded modular guidelines
|   |-- delegation.md                      # Extracted from pact-delegation-rules.md
|   |-- security.md                        # Extracted from S5 non-negotiables
|   |-- git-conventions.md                 # Commit standards, branch naming
|   |-- coding-standards.md               # From pact-principles.md CODE section
|   `-- context-economy.md                # Core context conservation rules
|
|-- protocols/                             # RETAINED: Complex reference docs (NOT @-referenced)
|   |-- pact-workflows.md                  # Loaded via skill, not @-reference
|   |-- pact-dispatch.md                   # Loaded via skill, not @-reference
|   |-- pact-pr-review.md                  # Loaded via skill, not @-reference
|   |-- algedonic.md                       # Loaded via skill, not @-reference
|   |-- pact-s5-policy.md                  # Decision framing (loaded on demand)
|   `-- ... (remaining protocols)
|
|-- commands/                              # RETAINED: PACT workflow commands
|   |-- orchestrate.md                     # UPDATED: +YAML frontmatter
|   |-- comPACT.md
|   |-- rePACT.md
|   |-- imPACT.md
|   |-- peer-review.md
|   |-- plan-mode.md
|   |-- pin-memory.md
|   `-- wrap-up.md
|
|-- skills/                                # RETAINED: 70+ skills
|   |-- pact-memory/
|   |   |-- SKILL.md                       # UPDATED: +user-invocable: false
|   |   |-- references/
|   |   `-- scripts/
|   |-- pact-agent-teams/
|   |   `-- SKILL.md                       # UPDATED: +user-invocable: false
|   |-- seo/
|   |   |-- SKILL.md
|   |   |-- reference.md                   # NEW: progressive disclosure
|   |   `-- examples.md                    # NEW: progressive disclosure
|   `-- ... (remaining skills)
|
|-- agents/                                # RETAINED but NOT primary (project-level preferred)
|
|-- agent-memory/                          # RETAINED: Per-agent persistent memory
|   |-- stax-architect/
|   |-- stax-backend-coder/
|   `-- ...
|
|-- hooks/                                 # RETAINED: 40+ hook scripts
|   |-- config/                            # NEW: Config separation
|   |   |-- hooks-config.json              # Team defaults (all hooks enabled)
|   |   `-- hooks-config.local.json        # Personal overrides (git-ignored)
|   |-- session_init.py
|   |-- phase_gate.py
|   `-- ... (remaining scripts)
|
|-- pact-memory/                           # RETAINED: SQLite knowledge store
|   `-- memory.db
|
`-- teams/                                 # RETAINED: Agent team configs
```

### Project (`HelixStax/.claude/`)

```
HelixStax/
|-- CLAUDE.md                              # RETAINED: Project overview (<100 lines)
|-- .mcp.json                              # NEW: Project-scoped MCP servers
|
`-- .claude/
    |-- settings.json                      # NEW: Team-shared project settings
    |-- settings.local.json                # RETAINED: Personal project overrides
    |
    |-- agents/                            # RETAINED: 23 agents
    |   |-- stax-architect.md              # UPDATED: +maxTurns, +effort, +disallowedTools
    |   |-- stax-backend-coder.md          # UPDATED: +maxTurns, +mcpServers
    |   |-- stax-vigil-monitor.md          # UPDATED: +background: true
    |   `-- ...
    |
    |-- rules/                             # NEW: Project-specific rules
    |   |-- helix-stax-conventions.md      # Domain-specific conventions
    |   `-- infrastructure-patterns.md     # K8s, Hetzner, deployment patterns
    |
    |-- commands/                           # NEW: Project-specific commands
    |   |-- deploy-check.md                # Pre-deployment validation
    |   `-- infra-status.md                # Cluster status check
    |
    `-- skills/                             # NEW: Project-specific skills
        `-- (moved from global if project-specific)
```

### Sub-Project (`helix-stax-infrastructure/`)

```
helix-stax-infrastructure/
`-- CLAUDE.md                              # NEW: Infra-specific context, lazy-loaded
```

---

## 5. Migration Steps

### Phase 1: Settings Hardening (1 hour)

1. Update `~/.claude/settings.json`:
   - Add `"ask"` rules for destructive bash commands (rm, docker, git push --force, kubectl delete)
   - Add `"env"` field with `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE: "80"`
   - Add `"attribution"` field matching Wakeem's commit preferences
2. Verify with `claude /doctor`

### Phase 2: Rules Extraction (2 hours)

1. Create `~/.claude/rules/` directory
2. Extract concise (<100 lines each) rules from protocols:
   - `delegation.md` -- core delegation rules (not full protocol, just the rules)
   - `security.md` -- S5 non-negotiables, security patterns
   - `git-conventions.md` -- commit format, branch naming, no Co-Author
   - `coding-standards.md` -- CODE phase principles
   - `context-economy.md` -- "your context is sacred" core rules
3. Remove corresponding `@` references from CLAUDE.md
4. Trim CLAUDE.md to <100 lines

### Phase 3: Agent Frontmatter Update (2 hours)

1. Add to all 23 agents:
   - `maxTurns: 10` (default; adjust per agent complexity)
   - `effort` matching L1/L2/L3 routing
2. Add to specific agents:
   - `background: true` on stax-vigil-monitor
   - `disallowedTools: Agent` on all coders (prevent sub-agent spawning)
   - `mcpServers` scoping where relevant
3. Add `user-invocable: false` to agent-only skills (~20 pact-* and n8n-* skills)

### Phase 4: Project-Level Config (1 hour)

1. Create `HelixStax/.claude/settings.json` with team-shared permissions
2. Create `HelixStax/.mcp.json` with project-relevant MCP servers
3. Create `HelixStax/.claude/rules/` with project-specific conventions

### Phase 5: Skill Progressive Disclosure (ongoing)

1. Identify top 10 most-used skills
2. For each: separate SKILL.md into SKILL.md + reference.md + examples.md
3. Audit all skill descriptions for brevity

---

## Appendix: Feature Coverage Matrix

| Feature | Best Practice | Helix Stax | Status |
|---------|:------------:|:----------:|:------:|
| CLAUDE.md (<200 lines) | Yes | Partial | Needs trim |
| Settings cascade (5-tier) | Yes | 3-tier | Needs expansion |
| Ask/Deny rules | Yes | No | Missing |
| Environment variables in settings | Yes | No | Missing |
| Attribution config | Yes | No | Missing |
| Rules directory | Yes | No | Missing |
| Skills with progressive disclosure | Yes | No | Missing |
| user-invocable: false | Yes | No | Missing |
| Agent maxTurns | Yes | No | Missing |
| Agent effort level | Yes | No | Missing |
| Agent background mode | Yes | No | Missing |
| Agent disallowedTools | Yes | No | Missing |
| Agent per-agent hooks | Yes | No | Missing |
| Agent per-agent MCP | Yes | No | Missing |
| Agent memory scopes (3) | Yes | 1 (user) | Partial |
| Hooks config separation | Yes | No | Missing |
| Prompt/agent hook types | Yes | No | Missing |
| Project-level .mcp.json | Yes | No | Missing |
| Project-level commands | Yes | No | Missing |
| Project-level rules | Yes | No | Missing |
| Cross-model workflow | Yes | No | Skipped |
| Monorepo CLAUDE.md | Yes | No | Missing |
| Auto-compact env var | Yes | No | Missing |
| Custom spinners | Yes | No | Optional |
| Status line | Yes | No | Optional |
| Multiple agent types (23) | No (3 demo) | Yes | Strength |
| 70+ skills library | No (3 demo) | Yes | Strength |
| 40+ hook scripts | No (1 dispatcher) | Yes | Strength |
| Three-layer memory (SQLite) | No | Yes | Strength |
| VSM governance (S1-S5) | No | Yes | Strength |
| Task-based orchestration | Basic | Advanced | Strength |
| Algedonic signals | No | Yes | Strength |
| 14 MCP servers | 5 recommended | 14 production | Strength |
