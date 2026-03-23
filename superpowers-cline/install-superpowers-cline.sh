#!/usr/bin/env bash
# ============================================================
# Superpowers for Cline — Installer
# Ports obra/superpowers skills to work with Cline (VS Code)
# ============================================================

set -e

SKILLS_DIR="$HOME/.agents/skills/superpowers"
COPILOT_SKILLS="$HOME/.copilot/skills/superpowers"

COMMAND="${1:-}"

if [ "$COMMAND" = "uninstall" ]; then
  if [ -z "${2:-}" ]; then
    echo "❌ 제거할 프로젝트 경로를 지정해야 합니다."
    echo "   사용법: bash $(basename "$0") uninstall /path/to/project"
    exit 1
  fi
  TARGET_PROJECT="$(cd "$2" && pwd)"
  echo ""
  echo "🗑️  Superpowers for Cline — 제거"
  echo "================================="
  echo "   프로젝트: $TARGET_PROJECT"
  echo ""

  rm -f  "$TARGET_PROJECT/.clinerules" && echo "✅ 삭제: .clinerules" || true
  rm -f  "$TARGET_PROJECT/AGENTS.md"   && echo "✅ 삭제: AGENTS.md"   || true
  rm -rf "$TARGET_PROJECT/docs/superpowers" && echo "✅ 삭제: docs/superpowers/" || true

  if [ -L "$SKILLS_DIR" ]; then
    rm "$SKILLS_DIR" && echo "✅ 삭제: $SKILLS_DIR (symlink)"
  elif [ -d "$SKILLS_DIR" ]; then
    rm -rf "$SKILLS_DIR" && echo "✅ 삭제: $SKILLS_DIR"
  fi

  # 개별 스킬 디렉토리 정리 (~/.agents/skills/<skill-name>/ 형태)
  AGENTS_SKILLS_BASE="$HOME/.agents/skills"
  SUPERPOWERS_SKILL_NAMES=(
    brainstorming
    dispatching-parallel-agents
    executing-plans
    finishing-a-development-branch
    receiving-code-review
    requesting-code-review
    subagent-driven-development
    systematic-debugging
    test-driven-development
    using-git-worktrees
    using-superpowers
    verification-before-completion
    writing-plans
    writing-skills
  )
  # 존재하는 개별 스킬 목록 확인
  existing_skills=()
  for skill_name in "${SUPERPOWERS_SKILL_NAMES[@]}"; do
    skill_path="$AGENTS_SKILLS_BASE/$skill_name"
    if [ -L "$skill_path" ] || [ -d "$skill_path" ]; then
      existing_skills+=("$skill_name")
    fi
  done
  if [ ${#existing_skills[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  다음 ${#existing_skills[@]}개 스킬 디렉토리가 $AGENTS_SKILLS_BASE 에 남아있습니다."
    echo "   (다른 도구와 공유 중일 수 있음)"
    for s in "${existing_skills[@]}"; do
      echo "   - $s"
    done
    printf "   삭제하시겠습니까? [y/N] "
    read -r confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      for skill_name in "${existing_skills[@]}"; do
        rm -rf "$AGENTS_SKILLS_BASE/$skill_name"
      done
      echo "✅ 삭제: ${#existing_skills[@]}개 개별 스킬 디렉토리"
    else
      echo "⏭️  개별 스킬 디렉토리 유지"
    fi
  fi

  echo ""
  echo "✅ Superpowers for Cline 제거 완료"
  exit 0
fi

if [ -z "$COMMAND" ]; then
  echo "❌ 프로젝트 경로를 지정해야 합니다."
  echo "   설치: bash $(basename "$0") /path/to/project"
  echo "   제거: bash $(basename "$0") uninstall /path/to/project"
  exit 1
fi
TARGET_PROJECT="$(cd "$1" && pwd)"

echo ""
echo "🦸 Superpowers for Cline — Installer"
echo "======================================"
echo ""

# ── Step 1: Shared skills directory ──────────────────────────
echo "📁 Setting up shared skills directory..."

[ -d "$SKILLS_DIR" ] || [ -L "$SKILLS_DIR" ] || mkdir -p "$SKILLS_DIR"

# If superpowers-copilot is already installed, symlink from it (no duplication)
if [ -d "$COPILOT_SKILLS" ]; then
  # Check if it's a real dir (not a symlink itself)
  if [ ! -L "$SKILLS_DIR" ] && [ "$(readlink -f "$COPILOT_SKILLS")" != "$(readlink -f "$SKILLS_DIR")" ]; then
    rm -rf "$SKILLS_DIR"
    ln -s "$COPILOT_SKILLS" "$SKILLS_DIR"
    echo "✅ Skills linked from existing Copilot install: $SKILLS_DIR → $COPILOT_SKILLS"
  else
    echo "✅ Skills already linked: $SKILLS_DIR"
  fi
else
  # Fresh clone of superpowers
  echo "📦 Cloning obra/superpowers..."
  CACHE_DIR="$HOME/.copilot/marketplace-cache/superpowers-raw"
  mkdir -p "$CACHE_DIR"

  if [ -d "$CACHE_DIR/.git" ]; then
    echo "   (cached) Pulling latest..."
    git -C "$CACHE_DIR" pull --quiet
  else
    git clone --quiet --depth=1 https://github.com/obra/superpowers.git "$CACHE_DIR"
  fi

  # Symlink skills
  rm -rf "$SKILLS_DIR"
  ln -s "$CACHE_DIR/skills" "$SKILLS_DIR"
  echo "✅ Skills installed: $SKILLS_DIR (14 skills)"
fi

# ── Step 2: Copy .clinerules to project ──────────────────────
echo ""
echo "📋 Installing .clinerules to project: $TARGET_PROJECT"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLINERULES_SRC="$SCRIPT_DIR/.clinerules"

# If run without a local .clinerules, download from repo
if [ ! -f "$CLINERULES_SRC" ]; then
  CLINERULES_SRC="/tmp/superpowers-clinerules"
  curl -fsSL \
    "https://raw.githubusercontent.com/DwainTR/superpowers-copilot/main/.clinerules" \
    -o "$CLINERULES_SRC" 2>/dev/null || true
fi

TARGET_RULES="$TARGET_PROJECT/.clinerules"

if [ -f "$TARGET_RULES" ]; then
  # Merge: append if superpowers block not already present
  if grep -q "superpowers-installed" "$TARGET_RULES" 2>/dev/null; then
    echo "✅ .clinerules already contains Superpowers block"
  else
    echo "" >> "$TARGET_RULES"
    cat "$CLINERULES_SRC" >> "$TARGET_RULES"
    echo "✅ Superpowers appended to existing .clinerules"
  fi
else
  cp "$CLINERULES_SRC" "$TARGET_RULES"
  echo "✅ .clinerules created: $TARGET_RULES"
fi

# ── Step 3: Create AGENTS.md if missing ──────────────────────
AGENTS_MD="$TARGET_PROJECT/AGENTS.md"
if [ ! -f "$AGENTS_MD" ]; then
  cat > "$AGENTS_MD" << 'EOF'
# Agent Instructions

## Superpowers
This project uses the Superpowers skills framework.
Skills are located at: ~/.agents/skills/superpowers/

Before any task, check for a relevant skill in that directory.
Read the SKILL.md file and follow it exactly.

## Project-specific overrides
<!-- Add your team's specific instructions below -->
EOF
  echo "✅ AGENTS.md created: $AGENTS_MD"
else
  echo "✅ AGENTS.md already exists (not modified)"
fi

# ── Step 4: Create docs directory structure ───────────────────
mkdir -p "$TARGET_PROJECT/docs/superpowers/specs"
mkdir -p "$TARGET_PROJECT/docs/superpowers/plans"
touch "$TARGET_PROJECT/docs/superpowers/.gitkeep"
echo "✅ Docs structure created: docs/superpowers/{specs,plans}/"

# ── Step 5: Update .gitignore ────────────────────────────────
GITIGNORE="$TARGET_PROJECT/.gitignore"
GITIGNORE_ENTRIES=(
  "docs/superpowers/plans/"
  "docs/superpowers/specs/"
  "docs/superpowers/.gitkeep"
  "/AGENTS.md"
  "/.clinerules"
)

echo ""
echo "🔒 Updating .gitignore..."

# 섹션이 아직 없을 때만 헤더+항목+푸터를 한 번에 추가
if ! grep -qF "# BEGIN superpowers-cline" "$GITIGNORE" 2>/dev/null; then
  {
    echo ""
    echo "# BEGIN superpowers-cline"
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
      echo "$entry"
    done
    echo "# END superpowers-cline"
  } >> "$GITIGNORE"
  echo "✅ Added superpowers-cline section to .gitignore"
else
  # 섹션이 이미 있으면 항목별로 누락된 것만 추가
  for entry in "${GITIGNORE_ENTRIES[@]}"; do
    if grep -qF "$entry" "$GITIGNORE" 2>/dev/null; then
      echo "✅ Already in .gitignore: $entry"
    else
      sed -i "/# END superpowers-cline/i $entry" "$GITIGNORE"
      echo "✅ Added to .gitignore: $entry"
    fi
  done
fi
echo ""
echo "🎉 Superpowers for Cline installed successfully!"
echo ""
echo "   Skills:   ~/.agents/skills/superpowers/ (14 skills)"
echo "   Rules:    $TARGET_RULES"
echo "   Agents:   $AGENTS_MD"
echo "   Docs:     docs/superpowers/"
echo ""
echo "   Next steps:"
echo "   1. Open VS Code and start a Cline session"
echo "   2. Verify: ask 'what superpowers skills do you have?'"
echo "   3. Try: 'Use the brainstorming skill to explore this idea'"
echo ""
echo "   Skills also available for:"
echo "   - GitHub Copilot CLI  (~/.copilot/skills/)"
echo "   - Cursor, Gemini CLI  (~/.agents/skills/superpowers/)"
echo ""
echo "   To uninstall:"
echo "   bash $(basename "$0") uninstall $TARGET_PROJECT"
