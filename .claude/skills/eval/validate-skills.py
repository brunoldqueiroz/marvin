#!/usr/bin/env python3
"""Validate all SKILL.md files against the agentskills.io format requirements.

Exit codes:
  0 — all checks passed
  1 — one or more checks failed
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SKILLS_GLOB = ".claude/skills/*/SKILL.md"
MAX_NAME_LEN = 64
MAX_DESCRIPTION_LEN = 1024
TOTAL_DESCRIPTION_BUDGET = 16_000
VALID_CATEGORIES = {"advisory", "workflow"}
REQUIRED_FRONTMATTER_FIELDS = {"name", "user-invocable", "description", "tools", "metadata"}
REQUIRED_METADATA_SUBFIELDS = {"author", "version", "category"}

# Mandatory body sections required for advisory skills only.
REQUIRED_BODY_SECTIONS = [
    "Tool Selection",
    "Core Principles",
    "Best Practices",
    "Anti-Patterns",
    "Examples",
    "Troubleshooting",
    "Review Checklist",
]

# ---------------------------------------------------------------------------
# Frontmatter parser
# ---------------------------------------------------------------------------

_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def _split_frontmatter(text: str) -> tuple[str, str]:
    """Return (frontmatter_block, body).

    Raises ValueError if the file does not start with a YAML frontmatter block.
    """
    m = _FRONTMATTER_RE.match(text)
    if not m:
        raise ValueError("File does not contain a valid YAML frontmatter block (--- ... ---)")
    return m.group(1), text[m.end() :]


def _parse_yaml_frontmatter(block: str) -> dict[str, object]:
    """Minimalist YAML parser — handles only the subset used in SKILL.md files.

    Supported constructs:
    - Scalar key: value
    - Folded/literal block scalar (key: >\n  ...) — collected as a single string
    - Sequence (key:\n  - item)
    - Nested mapping (key:\n  subkey: value)
    - Boolean values (true/false)
    """
    result: dict[str, object] = {}
    lines = block.splitlines()
    i = 0

    def _strip_inline(val: str) -> str | bool | None:
        val = val.strip()
        if val.lower() == "true":
            return True
        if val.lower() == "false":
            return False
        if val.lower() in ("null", "~", ""):
            return None
        # Strip surrounding quotes if present
        if (val.startswith('"') and val.endswith('"')) or (
            val.startswith("'") and val.endswith("'")
        ):
            return val[1:-1]
        return val

    while i < len(lines):
        line = lines[i]
        # Skip blank lines and comments
        if not line.strip() or line.strip().startswith("#"):
            i += 1
            continue

        # Top-level key: must start at column 0
        top_key_m = re.match(r"^(\S[^:]*?):\s*(.*)", line)
        if not top_key_m:
            i += 1
            continue

        key = top_key_m.group(1).strip()
        rest = top_key_m.group(2).strip()
        i += 1

        if rest in (">", "|", ">-", "|-"):
            # Block scalar — collect indented continuation lines
            scalar_lines: list[str] = []
            while i < len(lines) and (lines[i].startswith(" ") or lines[i].startswith("\t")):
                scalar_lines.append(lines[i].strip())
                i += 1
            result[key] = " ".join(scalar_lines)

        elif rest == "":
            # Could be a sequence or nested mapping
            items: list[str] = []
            nested: dict[str, object] = {}
            while i < len(lines) and lines[i].startswith(" "):
                sub = lines[i].strip()
                if sub.startswith("- "):
                    items.append(sub[2:].strip())
                elif ":" in sub:
                    sub_key_m = re.match(r"^(\S[^:]*?):\s*(.*)", sub)
                    if sub_key_m:
                        nested[sub_key_m.group(1).strip()] = _strip_inline(
                            sub_key_m.group(2)
                        )
                i += 1

            if items:
                result[key] = items
            elif nested:
                result[key] = nested
            else:
                result[key] = None

        else:
            result[key] = _strip_inline(rest)

    return result


# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------


def _check_name_format(name: object) -> list[str]:
    """Return list of error strings (empty = pass)."""
    errors: list[str] = []
    if not isinstance(name, str) or not name:
        errors.append("  [FAIL] name: field is missing or not a string")
        return errors
    if not re.fullmatch(r"[a-z][a-z0-9-]*", name):
        errors.append(
            f"  [FAIL] name: '{name}' must be lowercase letters, digits, and hyphens only"
        )
    if len(name) > MAX_NAME_LEN:
        errors.append(
            f"  [FAIL] name: '{name}' exceeds {MAX_NAME_LEN} characters (got {len(name)})"
        )
    return errors


def _check_description(description: object) -> tuple[list[str], int]:
    """Return (error_list, char_count)."""
    errors: list[str] = []
    if not isinstance(description, str) or not description.strip():
        errors.append("  [FAIL] description: field is missing or empty")
        return errors, 0
    char_count = len(description.strip())
    if char_count >= MAX_DESCRIPTION_LEN:
        errors.append(
            f"  [FAIL] description: {char_count} chars >= {MAX_DESCRIPTION_LEN} limit"
        )
    return errors, char_count


def _check_required_fields(fm: dict[str, object]) -> list[str]:
    errors: list[str] = []
    for field in sorted(REQUIRED_FRONTMATTER_FIELDS):
        if field not in fm:
            errors.append(f"  [FAIL] required frontmatter field missing: '{field}'")
    return errors


def _check_metadata(metadata: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(metadata, dict):
        errors.append("  [FAIL] metadata: must be a mapping (got scalar or list)")
        return errors
    for sub in sorted(REQUIRED_METADATA_SUBFIELDS):
        if sub not in metadata:
            errors.append(f"  [FAIL] metadata.{sub}: required sub-field missing")
    return errors


def _check_category(metadata: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(metadata, dict):
        return errors  # already reported above
    category = metadata.get("category")
    if category not in VALID_CATEGORIES:
        errors.append(
            f"  [FAIL] metadata.category: '{category}' must be one of {sorted(VALID_CATEGORIES)}"
        )
    return errors


def _check_user_invocable(value: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, bool):
        errors.append(
            f"  [FAIL] user-invocable: must be boolean true/false (got {value!r})"
        )
    return errors


def _check_body_sections(body: str) -> list[str]:
    """Check that all 7 mandatory sections are present as ## headings."""
    errors: list[str] = []
    headings = re.findall(r"^##\s+(.+)", body, re.MULTILINE)
    heading_texts = {h.strip() for h in headings}
    for section in REQUIRED_BODY_SECTIONS:
        if section not in heading_texts:
            errors.append(f"  [FAIL] body section missing: '## {section}'")
    return errors


# ---------------------------------------------------------------------------
# Per-skill validator
# ---------------------------------------------------------------------------


def validate_skill(path: Path) -> tuple[bool, int]:
    """Validate a single SKILL.md.

    Returns (all_passed, description_char_count).
    Prints results to stdout.
    """
    print(f"\n{'=' * 60}")
    print(f"Skill: {path}")
    print(f"{'=' * 60}")

    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"  [FAIL] Cannot read file: {exc}")
        return False, 0

    # Parse frontmatter
    try:
        fm_block, body = _split_frontmatter(text)
    except ValueError as exc:
        print(f"  [FAIL] {exc}")
        return False, 0

    try:
        fm = _parse_yaml_frontmatter(fm_block)
    except Exception as exc:  # noqa: BLE001
        print(f"  [FAIL] Frontmatter parse error: {exc}")
        return False, 0

    all_errors: list[str] = []

    # --- Check 1: Required frontmatter fields ---
    field_errors = _check_required_fields(fm)
    all_errors.extend(field_errors)

    # --- Check 2: name format ---
    name_errors = _check_name_format(fm.get("name"))
    all_errors.extend(name_errors)

    # --- Check 3 & 4: description present and length ---
    desc_errors, desc_chars = _check_description(fm.get("description"))
    all_errors.extend(desc_errors)

    # --- Check 5: user-invocable boolean ---
    if "user-invocable" in fm:
        all_errors.extend(_check_user_invocable(fm["user-invocable"]))

    # --- Check 6: metadata subfields ---
    if "metadata" in fm:
        all_errors.extend(_check_metadata(fm["metadata"]))

    # --- Check 7: category valid ---
    all_errors.extend(_check_category(fm.get("metadata")))

    # --- Check 8: mandatory body sections (advisory only) ---
    metadata = fm.get("metadata")
    category = metadata.get("category") if isinstance(metadata, dict) else None
    if category == "advisory":
        all_errors.extend(_check_body_sections(body))

    # Report results
    if all_errors:
        for err in all_errors:
            print(err)
        skill_name = fm.get("name", path.parent.name)
        print(f"\n  Result: FAIL ({len(all_errors)} issue(s)) — {skill_name}")
        return False, desc_chars
    else:
        skill_name = fm.get("name", path.parent.name)
        desc_info = f"description={desc_chars} chars"
        category_info = f"category={category}"
        print(f"  [PASS] All checks passed — {skill_name} ({category_info}, {desc_info})")
        return True, desc_chars


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> int:
    repo_root = Path(__file__).parent.parent.parent.parent  # .claude/skills/eval/validate-skills.py
    skill_paths = sorted(repo_root.glob(SKILLS_GLOB))

    if not skill_paths:
        print(f"ERROR: No SKILL.md files found matching '{SKILLS_GLOB}' under {repo_root}")
        return 1

    total_skills = len(skill_paths)
    total_passed = 0
    total_failed = 0
    total_desc_chars = 0

    for path in skill_paths:
        passed, desc_chars = validate_skill(path)
        total_desc_chars += desc_chars
        if passed:
            total_passed += 1
        else:
            total_failed += 1

    # --- Global check: total description budget ---
    print(f"\n{'=' * 60}")
    print("Global Checks")
    print(f"{'=' * 60}")
    budget_ok = total_desc_chars < TOTAL_DESCRIPTION_BUDGET
    budget_status = "PASS" if budget_ok else "FAIL"
    print(
        f"  [{budget_status}] Total description chars: {total_desc_chars} / {TOTAL_DESCRIPTION_BUDGET} budget"
    )
    if not budget_ok:
        total_failed += 1

    # --- Summary ---
    print(f"\n{'=' * 60}")
    print("Summary")
    print(f"{'=' * 60}")
    print(f"  Skills evaluated : {total_skills}")
    print(f"  Passed           : {total_passed}")
    print(f"  Failed           : {total_failed}")
    print(f"  Description chars: {total_desc_chars} / {TOTAL_DESCRIPTION_BUDGET}")

    overall = "ALL PASSED" if total_failed == 0 else f"{total_failed} FAILED"
    print(f"\n  Overall: {overall}")

    return 0 if total_failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
