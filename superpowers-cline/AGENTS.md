# Agent Instructions

## Superpowers Skills Framework

This project uses the Superpowers skills framework (obra/superpowers).
You have 14 skills available at: `~/.agents/skills/superpowers/`

### How to use skills (Cline)
You do NOT have a `Skill` tool. Instead:
1. Read the file: `~/.agents/skills/superpowers/<skill-name>/SKILL.md`
2. Announce: "Using [skill] to [purpose]"
3. Follow the skill's process EXACTLY — do not adapt or skip steps

### Skill selection
- ANY creative/build request → `brainstorming` first
- ANY bug/unexpected behavior → `systematic-debugging` first  
- Writing code (after plan) → `test-driven-development`
- After design approved → `writing-plans`
- If 1% chance a skill applies → invoke it

---

## Project Conventions

<!-- Add team-specific rules here, e.g.: -->
<!-- - Language: TypeScript + ESM -->
<!-- - Test runner: vitest -->
<!-- - Lint: eslint + prettier (run before every commit) -->
<!-- - Branch naming: feat/*, fix/*, chore/* -->

---

## User Instructions Override

These instructions take highest priority.
If a skill contradicts a rule here, follow THIS file.
