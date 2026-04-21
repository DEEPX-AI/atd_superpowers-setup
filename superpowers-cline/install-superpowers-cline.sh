#!/usr/bin/env bash
# ============================================================
# Superpowers for Cline — Installer
# Ports obra/superpowers skills to work with Cline (VS Code)
#
# 사용법:
#   bash install-superpowers-cline.sh <project>              # 전역 설치 (~/.agents/skills/superpowers)
#   bash install-superpowers-cline.sh <project> --local      # 프로젝트 로컬 (<project>/.superpowers/skills)
#   bash install-superpowers-cline.sh uninstall <project> [--local]
# ============================================================

set -e

# ── 인자 파싱 ─────────────────────────────────────────────────
LOCAL_MODE=false
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_MODE=true ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]}"

COMMAND="${1:-}"

# ── 공통 경로 결정 ────────────────────────────────────────────
resolve_paths() {
  if $LOCAL_MODE; then
    SKILLS_DIR="$TARGET_PROJECT/.superpowers/skills"
    CACHE_DIR="$TARGET_PROJECT/.superpowers/cache/obra-superpowers"
    SKILLS_REF_PATH=".superpowers/skills"      # .clinerules/AGENTS.md 내부 표기용 (상대경로)
  else
    SKILLS_DIR="$HOME/.agents/skills/superpowers"
    CACHE_DIR="$HOME/.copilot/marketplace-cache/superpowers-raw"
    SKILLS_REF_PATH="~/.agents/skills/superpowers"
  fi
  COPILOT_SKILLS="$HOME/.copilot/skills/superpowers"  # 전역 모드에서만 사용
}

# ── uninstall 처리 ───────────────────────────────────────────
if [ "$COMMAND" = "uninstall" ]; then
  if [ -z "${2:-}" ]; then
    echo "❌ 제거할 프로젝트 경로를 지정해야 합니다."
    echo "   사용법: bash $(basename "$0") uninstall /path/to/project [--local]"
    exit 1
  fi
  TARGET_PROJECT="$(cd "$2" && pwd)"
  resolve_paths

  echo ""
  echo "🗑️  Superpowers for Cline — 제거"
  echo "================================="
  echo "   프로젝트: $TARGET_PROJECT"
  $LOCAL_MODE && echo "   모드:    --local" || echo "   모드:    전역"
  echo ""

  rm -f  "$TARGET_PROJECT/.clinerules" && echo "✅ 삭제: .clinerules" || true
  rm -f  "$TARGET_PROJECT/AGENTS.md"   && echo "✅ 삭제: AGENTS.md"   || true
  rm -rf "$TARGET_PROJECT/docs/superpowers" && echo "✅ 삭제: docs/superpowers/" || true

  if $LOCAL_MODE; then
    # 로컬 모드: .superpowers/ 디렉토리 통째로 정리
    if [ -d "$TARGET_PROJECT/.superpowers" ]; then
      rm -rf "$TARGET_PROJECT/.superpowers" && echo "✅ 삭제: $TARGET_PROJECT/.superpowers"
    fi
    echo ""
    echo "✅ Superpowers for Cline (local) 제거 완료"
    exit 0
  fi

  # 전역 모드 기존 로직
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
  echo "   설치: bash $(basename "$0") /path/to/project [--local]"
  echo "   제거: bash $(basename "$0") uninstall /path/to/project [--local]"
  exit 1
fi
TARGET_PROJECT="$(cd "$1" && pwd)"
resolve_paths

echo ""
echo "🦸 Superpowers for Cline — Installer"
echo "======================================"
echo "   프로젝트: $TARGET_PROJECT"
$LOCAL_MODE && echo "   모드:    --local ($SKILLS_DIR)" || echo "   모드:    전역 ($SKILLS_DIR)"
echo ""

# ── Step 1: Skills directory 준비 ────────────────────────────
echo "📁 Setting up skills directory..."

if $LOCAL_MODE; then
  # 로컬 모드: 프로젝트 내부에 독립 clone → symlink
  mkdir -p "$TARGET_PROJECT/.superpowers"
  if [ -d "$CACHE_DIR/.git" ]; then
    echo "   (cached) Pulling latest..."
    git -C "$CACHE_DIR" pull --quiet --ff-only 2>/dev/null || echo "   ⚠️  업데이트 실패 (오프라인?). 기존 버전 사용"
  else
    echo "📦 Cloning obra/superpowers into project..."
    mkdir -p "$(dirname "$CACHE_DIR")"
    git clone --quiet --depth=1 https://github.com/obra/superpowers.git "$CACHE_DIR"
  fi
  # Skills symlink
  if [ -L "$SKILLS_DIR" ] || [ -d "$SKILLS_DIR" ]; then
    rm -rf "$SKILLS_DIR"
  fi
  mkdir -p "$(dirname "$SKILLS_DIR")"
  ln -s "$CACHE_DIR/skills" "$SKILLS_DIR"
  echo "✅ Skills linked: $SKILLS_DIR → $CACHE_DIR/skills"
else
  # 전역 모드: 기존 로직
  [ -d "$SKILLS_DIR" ] || [ -L "$SKILLS_DIR" ] || mkdir -p "$SKILLS_DIR"

  if [ -d "$COPILOT_SKILLS" ]; then
    if [ ! -L "$SKILLS_DIR" ] && [ "$(readlink -f "$COPILOT_SKILLS")" != "$(readlink -f "$SKILLS_DIR")" ]; then
      rm -rf "$SKILLS_DIR"
      ln -s "$COPILOT_SKILLS" "$SKILLS_DIR"
      echo "✅ Skills linked from existing Copilot install: $SKILLS_DIR → $COPILOT_SKILLS"
    else
      echo "✅ Skills already linked: $SKILLS_DIR"
    fi
  else
    echo "📦 Cloning obra/superpowers..."
    mkdir -p "$CACHE_DIR"
    if [ -d "$CACHE_DIR/.git" ]; then
      echo "   (cached) Pulling latest..."
      git -C "$CACHE_DIR" pull --quiet
    else
      git clone --quiet --depth=1 https://github.com/obra/superpowers.git "$CACHE_DIR"
    fi
    rm -rf "$SKILLS_DIR"
    ln -s "$CACHE_DIR/skills" "$SKILLS_DIR"
    echo "✅ Skills installed: $SKILLS_DIR (14 skills)"
  fi
fi

# ── Step 2: .clinerules 설치 (경로 치환) ─────────────────────
echo ""
echo "📋 Installing .clinerules to project: $TARGET_PROJECT"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLINERULES_SRC="$SCRIPT_DIR/.clinerules"

if [ ! -f "$CLINERULES_SRC" ]; then
  CLINERULES_SRC="/tmp/superpowers-clinerules"
  curl -fsSL \
    "https://raw.githubusercontent.com/DwainTR/superpowers-copilot/main/.clinerules" \
    -o "$CLINERULES_SRC" 2>/dev/null || true
fi

TARGET_RULES="$TARGET_PROJECT/.clinerules"

# 경로 치환된 .clinerules 내용을 준비 (--local 모드일 때만 실제 치환 발생)
# 임시 파일에 치환본 생성
TMP_RULES=$(mktemp)
if $LOCAL_MODE; then
  # ~/.agents/skills/superpowers  →  .superpowers/skills
  sed 's|~/\.agents/skills/superpowers|.superpowers/skills|g' "$CLINERULES_SRC" > "$TMP_RULES"
else
  cp "$CLINERULES_SRC" "$TMP_RULES"
fi

if [ -f "$TARGET_RULES" ]; then
  if grep -q "superpowers-installed" "$TARGET_RULES" 2>/dev/null; then
    echo "✅ .clinerules already contains Superpowers block"
  else
    echo "" >> "$TARGET_RULES"
    cat "$TMP_RULES" >> "$TARGET_RULES"
    echo "✅ Superpowers appended to existing .clinerules"
  fi
else
  cp "$TMP_RULES" "$TARGET_RULES"
  echo "✅ .clinerules created: $TARGET_RULES"
fi
rm -f "$TMP_RULES"

# ── Step 3: AGENTS.md 생성 (경로 치환) ───────────────────────
AGENTS_MD="$TARGET_PROJECT/AGENTS.md"
if [ ! -f "$AGENTS_MD" ]; then
  cat > "$AGENTS_MD" << EOF
# Agent Instructions

## Superpowers
This project uses the Superpowers skills framework.
Skills are located at: $SKILLS_REF_PATH/

Before any task, check for a relevant skill in that directory.
Read the SKILL.md file and follow it exactly.

## Project-specific overrides
<!-- Add your team's specific instructions below -->
EOF
  echo "✅ AGENTS.md created: $AGENTS_MD"
else
  echo "✅ AGENTS.md already exists (not modified)"
fi

# ── Step 4: docs/superpowers 디렉토리 구조 ──────────────────
mkdir -p "$TARGET_PROJECT/docs/superpowers/specs"
mkdir -p "$TARGET_PROJECT/docs/superpowers/plans"
touch "$TARGET_PROJECT/docs/superpowers/.gitkeep"
echo "✅ Docs structure created: docs/superpowers/{specs,plans}/"

# ── Step 5: .gitignore 업데이트 ──────────────────────────────
GITIGNORE="$TARGET_PROJECT/.gitignore"
GITIGNORE_ENTRIES=(
  "docs/superpowers/plans/"
  "docs/superpowers/specs/"
  "docs/superpowers/.gitkeep"
  "/AGENTS.md"
  "/.clinerules"
)
if $LOCAL_MODE; then
  GITIGNORE_ENTRIES+=(
    "/.superpowers/cache/"
    "/.superpowers/skills"
  )
fi

echo ""
echo "🔒 Updating .gitignore..."

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
if $LOCAL_MODE; then
  echo "   Skills:   $SKILLS_DIR (14 skills, project-local)"
else
  echo "   Skills:   ~/.agents/skills/superpowers/ (14 skills)"
fi
echo "   Rules:    $TARGET_RULES"
echo "   Agents:   $AGENTS_MD"
echo "   Docs:     docs/superpowers/"
echo ""
echo "   Next steps:"
echo "   1. Open VS Code and start a Cline session"
echo "   2. Verify: ask 'what superpowers skills do you have?'"
echo "   3. Try: 'Use the brainstorming skill to explore this idea'"
echo ""
if ! $LOCAL_MODE; then
  echo "   Skills also available for:"
  echo "   - GitHub Copilot CLI  (~/.copilot/skills/)"
  echo "   - Cursor, Gemini CLI  (~/.agents/skills/superpowers/)"
  echo ""
fi
echo "   To uninstall:"
if $LOCAL_MODE; then
  echo "   bash $(basename "$0") uninstall $TARGET_PROJECT --local"
else
  echo "   bash $(basename "$0") uninstall $TARGET_PROJECT"
fi
