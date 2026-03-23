#!/usr/bin/env python3
"""
Cline Session Export - Advanced Version
ui_messages.json + api_conversation_history.json + focus_chain.md + task_metadata.json
→ 읽기 좋은 Markdown 파일로 변환
"""

import json
import re
import sys
import os
from datetime import datetime, timezone, timedelta
from pathlib import Path


# ── 설정 ────────────────────────────────────────────────────────────────────

KST = timezone(timedelta(hours=9))

TOOL_EMOJI = {
    "readFile":           "📄",
    "writeToFile":        "✍️",
    "replaceInFile":      "✏️",
    "listFiles":          "📁",
    "listFilesRecursive": "📂",
    "execute_command":    "💻",
    "command":            "💻",
    "read_file":          "📄",
    "write_to_file":      "✍️",
    "replace_in_file":    "✏️",
    "list_files":         "📁",
    "ask_followup_question": "❓",
    "attempt_completion": "✅",
}

TOOL_LABEL = {
    "readFile":           "파일 읽기",
    "writeToFile":        "파일 작성",
    "replaceInFile":      "파일 수정",
    "listFiles":          "디렉토리 목록",
    "listFilesRecursive": "디렉토리 트리",
    "execute_command":    "명령어 실행",
    "command":            "명령어 실행",
    "read_file":          "파일 읽기",
    "write_to_file":      "파일 작성",
    "replace_in_file":    "파일 수정",
    "list_files":         "디렉토리 목록",
    "ask_followup_question": "질문",
    "attempt_completion": "완료",
}


# ── 유틸 ────────────────────────────────────────────────────────────────────

def ts_to_str(ts_ms):
    """밀리초 타임스탬프 → KST 문자열"""
    try:
        dt = datetime.fromtimestamp(ts_ms / 1000, tz=KST)
        return dt.strftime("%Y-%m-%d %H:%M:%S KST")
    except Exception:
        return str(ts_ms)


def strip_env_details(text):
    """<environment_details> 블록 제거 (노이즈 감소)"""
    return re.sub(r"<environment_details>.*?</environment_details>", "", text, flags=re.DOTALL).strip()


def strip_xml_tag(text, tag):
    """특정 XML 태그 + 내용 제거"""
    return re.sub(rf"<{tag}>.*?</{tag}>", "", text, flags=re.DOTALL).strip()


def extract_xml(text, tag):
    """XML 태그 내용 추출, 없으면 None"""
    m = re.search(rf"<{tag}>(.*?)</{tag}>", text, re.DOTALL)
    return m.group(1).strip() if m else None


def extract_tool_calls(text):
    """어시스턴트 응답에서 tool call XML 블록 파싱"""
    tool_tags = [
        "read_file", "write_to_file", "replace_in_file", "list_files",
        "execute_command", "ask_followup_question", "attempt_completion",
        "readFile", "writeToFile", "replaceInFile", "listFilesRecursive",
        "listFiles",
    ]
    tools = []
    for tag in tool_tags:
        pattern = rf"<{tag}>(.*?)</{tag}>"
        for m in re.finditer(pattern, text, re.DOTALL):
            inner = m.group(1).strip()
            info = {"tool": tag, "raw": inner}

            path = extract_xml(inner, "path")
            if path:
                info["path"] = path

            content = extract_xml(inner, "content")
            if content:
                info["content"] = content

            diff = extract_xml(inner, "diff")
            if diff:
                info["diff"] = diff

            cmd = extract_xml(inner, "command")
            if cmd:
                info["command"] = cmd

            result = extract_xml(inner, "result")
            if result:
                info["result"] = result

            question = extract_xml(inner, "question")
            if question:
                info["question"] = question

            tools.append(info)
    return tools


def parse_tool_result_message(text):
    """user 역할 메시지에서 tool result 파싱"""
    # [readFile for 'path'] Result:\n---\ncontent
    m = re.match(r"\[(\w+) for '([^']+)'\] Result:\n---\n(.*)", text, re.DOTALL)
    if m:
        return {"tool": m.group(1), "path": m.group(2), "result": m.group(3).strip()}
    
    # Command output: ...
    m = re.match(r"Command: (.+?)\nOutput:\n(.*)", text, re.DOTALL)
    if m:
        return {"tool": "execute_command", "command": m.group(1), "output": m.group(2).strip()}
    
    return None


def format_tool_block_md(tool_info, is_result=False):
    """tool call / result → Markdown 블록"""
    name = tool_info.get("tool", "unknown")
    emoji = TOOL_EMOJI.get(name, "🔧")
    label = TOOL_LABEL.get(name, name)

    lines = []
    if is_result:
        path = tool_info.get("path", "")
        result = tool_info.get("result", "")
        output = tool_info.get("output", "")
        command = tool_info.get("command", "")
        
        header = f"> **{emoji} [{label} 결과]**"
        if path:
            header += f" `{path}`"
        if command:
            header += f" `{command}`"
        lines.append(header)
        
        content = result or output
        if content:
            # 너무 긴 결과는 접기
            preview_lines = content.split("\n")[:30]
            preview = "\n".join(preview_lines)
            if len(content.split("\n")) > 30:
                preview += f"\n... (이하 {len(content.split(chr(10))) - 30}줄 생략)"
            lines.append(f">\n> ```\n> " + preview.replace("\n", "\n> ") + "\n> ```")
    else:
        # Tool call
        path = tool_info.get("path", "")
        content = tool_info.get("content", "")
        diff = tool_info.get("diff", "")
        command = tool_info.get("command", "")
        question = tool_info.get("question", "")
        result = tool_info.get("result", "")  # attempt_completion result

        header = f"> **{emoji} [{label}]**"
        if path:
            header += f" `{path}`"
        if command:
            header += f" `{command}`"
        lines.append(header)

        if question:
            lines.append(f">\n> {question}")

        if result:
            lines.append(f">\n> {result}")

        if content:
            preview = "\n".join(content.split("\n")[:20])
            if len(content.split("\n")) > 20:
                preview += f"\n... (이하 생략)"
            lines.append(f">\n> ```\n> " + preview.replace("\n", "\n> ") + "\n> ```")

        if diff:
            preview = "\n".join(diff.split("\n")[:30])
            if len(diff.split("\n")) > 30:
                preview += f"\n... (이하 생략)"
            lines.append(f">\n> ```diff\n> " + preview.replace("\n", "\n> ") + "\n> ```")

    return "\n".join(lines)


# ── 메인 파싱 ────────────────────────────────────────────────────────────────

def load_files(base_path):
    """파일 로드 - 경로 prefix로 자동 탐색"""
    base = Path(base_path)
    
    # 단일 파일이면 디렉토리로 변환
    if base.is_file():
        base = base.parent
    
    # prefix 찾기 (타임스탬프 기반)
    api_files = list(base.glob("*_api_conversation_history.json"))
    ui_files = list(base.glob("*_ui_messages.json"))
    meta_files = list(base.glob("*_task_metadata.json"))
    focus_files = list(base.glob("*_focus_chain_*.md"))
    
    if not api_files or not ui_files:
        raise FileNotFoundError(f"api_conversation_history.json 또는 ui_messages.json 파일을 찾을 수 없습니다: {base}")
    
    result = {}
    
    with open(api_files[0]) as f:
        result["api"] = json.load(f)
    
    with open(ui_files[0]) as f:
        result["ui"] = json.load(f)
    
    if meta_files:
        with open(meta_files[0]) as f:
            result["meta"] = json.load(f)
    
    if focus_files:
        with open(focus_files[0]) as f:
            result["focus"] = f.read()
        result["focus_filename"] = focus_files[0].name
    
    result["task_id"] = api_files[0].stem.replace("_api_conversation_history", "")
    
    return result


def build_markdown(data):
    """전체 Markdown 생성"""
    api_msgs = data["api"]
    ui_msgs = data["ui"]
    meta = data.get("meta", {})
    focus = data.get("focus", "")
    task_id = data.get("task_id", "unknown")
    
    # 타임스탬프 범위
    timestamps = [m.get("ts", 0) for m in api_msgs if m.get("ts")]
    start_ts = min(timestamps) if timestamps else 0
    end_ts = max(timestamps) if timestamps else 0
    
    # 모델 정보 수집
    model_usage = meta.get("model_usage", [])
    models_used = list(dict.fromkeys([m.get("model_id", "") for m in model_usage]))
    
    # 환경 정보
    env_history = meta.get("environment_history", [])
    env = env_history[0] if env_history else {}
    
    # ui_messages에서 초기 task 텍스트 추출
    task_items = [m for m in ui_msgs if m.get("say") == "task"]
    initial_task = task_items[0].get("text", "") if task_items else ""
    
    lines = []
    
    # ── 헤더 ──────────────────────────────────────────────────────────────────
    lines += [
        "# 🤖 Cline Session Export",
        "",
        "---",
        "",
        "## 📋 세션 정보",
        "",
        f"| 항목 | 내용 |",
        f"|------|------|",
        f"| **Task ID** | `{task_id}` |",
        f"| **시작 시각** | {ts_to_str(start_ts)} |",
        f"| **종료 시각** | {ts_to_str(end_ts)} |",
        f"| **메시지 수** | API {len(api_msgs)}개 / UI {len(ui_msgs)}개 |",
        f"| **사용 모델** | {', '.join(f'`{m}`' for m in models_used) if models_used else '알 수 없음'} |",
        f"| **환경** | {env.get('host_name','?')} {env.get('host_version','?')} / Cline {env.get('cline_version','?')} |",
        f"| **OS** | {env.get('os_name','?')} {env.get('os_version','?')} ({env.get('os_arch','?')}) |",
        "",
    ]
    
    # ── 초기 태스크 ──────────────────────────────────────────────────────────
    if initial_task:
        lines += [
            "## 🎯 초기 태스크",
            "",
            f"> {initial_task}",
            "",
        ]
    
    # ── Focus Chain ───────────────────────────────────────────────────────────
    if focus:
        lines += [
            "## ✅ Focus Chain (진행 현황)",
            "",
            focus.strip(),
            "",
        ]
    
    # ── 파일 변경 이력 ────────────────────────────────────────────────────────
    files_in_context = meta.get("files_in_context", [])
    if files_in_context:
        edited = [f for f in files_in_context if f.get("cline_edit_date") or f.get("user_edit_date")]
        # 중복 경로 제거 (마지막 항목 우선)
        seen = {}
        for f in edited:
            seen[f["path"]] = f
        edited_unique = list(seen.values())
        
        if edited_unique:
            lines += [
                "## 📝 변경된 파일",
                "",
                "| 파일 | 편집자 |",
                "|------|--------|",
            ]
            for f in edited_unique:
                path = f["path"]
                if f.get("user_edit_date"):
                    editor = "👤 사용자"
                elif f.get("cline_edit_date"):
                    editor = "🤖 Cline"
                else:
                    editor = "-"
                lines.append(f"| `{path}` | {editor} |")
            lines.append("")
    
    # ── 대화 내용 ─────────────────────────────────────────────────────────────
    lines += [
        "---",
        "",
        "## 💬 대화 내용",
        "",
    ]
    
    # ui_messages에서 user_feedback 수집 (타임스탬프 → 텍스트 매핑)
    ui_feedback_map = {}
    for m in ui_msgs:
        if m.get("say") == "user_feedback":
            ui_feedback_map[m.get("ts", 0)] = m.get("text", "")
    
    # api_conversation_history 기반으로 메시지 렌더링
    turn_num = 0
    for idx, msg in enumerate(api_msgs):
        role = msg.get("role", "")
        content = msg.get("content", [])
        ts = msg.get("ts", 0)
        
        if not isinstance(content, list):
            content = [{"type": "text", "text": str(content)}]
        
        # 전체 텍스트 합치기
        full_text = "\n\n".join(
            block.get("text", "") for block in content
            if block.get("type") == "text"
        )
        
        if role == "user":
            # environment_details 제거
            clean = strip_env_details(full_text)
            
            # tool result 패턴 확인
            tool_result = parse_tool_result_message(clean)
            
            # task 메시지 (첫 user)
            is_initial_task = "<task>" in clean and idx == 0
            
            if is_initial_task:
                # 이미 위에서 출력함 - skip
                continue
            
            # task_progress 포함 여부
            task_progress = extract_xml(clean, "task_progress")
            
            # environment_details 이후 남은 텍스트 정리
            clean2 = clean
            for tag in ["task_progress"]:
                clean2 = strip_xml_tag(clean2, tag).strip()
            
            if tool_result:
                # Tool result 메시지
                lines.append(format_tool_block_md(tool_result, is_result=True))
                lines.append("")
            elif clean2.strip():
                # 사용자 피드백 또는 일반 메시지
                # <task> 태그 처리
                task_content = extract_xml(clean2, "task")
                if task_content:
                    lines += [
                        f"### 👤 사용자 입력",
                        "",
                        f"> {task_content}",
                        "",
                    ]
                else:
                    # 일반 사용자 메시지
                    clean2 = re.sub(r"<[^>]+>", "", clean2).strip()
                    if clean2:
                        lines += [
                            f"### 👤 사용자",
                            "",
                            clean2,
                            "",
                        ]
        
        elif role == "assistant":
            turn_num += 1
            ts_str = f" <sub>{ts_to_str(ts)}</sub>" if ts else ""
            
            lines += [
                f"### 🤖 Cline (턴 {turn_num}){ts_str}",
                "",
            ]
            
            # thinking 블록 추출 및 제거
            thinking = extract_xml(full_text, "thinking")
            clean = full_text
            if thinking:
                clean = strip_xml_tag(clean, "thinking").strip()
                # thinking을 접을 수 있는 details로 표시
                thinking_preview = thinking[:200].replace("\n", " ")
                if len(thinking) > 200:
                    thinking_preview += "..."
                lines += [
                    "<details>",
                    f"<summary>💭 내부 추론 (thinking)</summary>",
                    "",
                    "```",
                    thinking,
                    "```",
                    "",
                    "</details>",
                    "",
                ]
            
            # task_progress 추출
            task_progress = extract_xml(clean, "task_progress")
            clean = strip_xml_tag(clean, "task_progress").strip()
            
            # tool calls 추출
            tool_calls = extract_tool_calls(clean)
            
            # tool call XML 태그들 제거한 순수 텍스트
            for tag in [
                "read_file", "write_to_file", "replace_in_file", "list_files",
                "execute_command", "ask_followup_question", "attempt_completion",
                "readFile", "writeToFile", "replaceInFile", "listFilesRecursive", "listFiles",
            ]:
                clean = re.sub(rf"<{tag}>.*?</{tag}>", "", clean, flags=re.DOTALL)
            
            clean = clean.strip()
            
            # 순수 텍스트 출력
            if clean:
                lines += [clean, ""]
            
            # task_progress 출력
            if task_progress:
                lines += [
                    "**📋 Task Progress:**",
                    "",
                    task_progress,
                    "",
                ]
            
            # tool calls 출력
            for tc in tool_calls:
                lines.append(format_tool_block_md(tc, is_result=False))
                lines.append("")
    
    # ── 푸터 ──────────────────────────────────────────────────────────────────
    lines += [
        "---",
        "",
        f"*Generated by cline_export.py — {datetime.now(KST).strftime('%Y-%m-%d %H:%M:%S KST')}*",
    ]
    
    return "\n".join(lines)


# ── 진입점 ───────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        # 기본값: 현재 디렉토리
        input_path = "."
    else:
        input_path = sys.argv[1]
    
    output_path = sys.argv[2] if len(sys.argv) >= 3 else None
    
    print(f"📂 입력 경로: {input_path}")
    
    data = load_files(input_path)
    task_id = data["task_id"]
    
    if not output_path:
        output_path = f"{task_id}_export.md"
    
    md = build_markdown(data)
    
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(md)
    
    print(f"✅ 저장 완료: {output_path}")
    print(f"   크기: {len(md):,} 자 / {len(md.splitlines())} 줄")


if __name__ == "__main__":
    main()
