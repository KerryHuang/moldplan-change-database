#!/usr/bin/env python3
"""Pre-commit hook: runs dotnet test before git commit. Blocks on failure (exit 2)."""
import io
import json
import subprocess
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

data = json.load(sys.stdin)
project_dir = Path(data.get("cwd", "."))
test_project = project_dir / "tests" / "MoldplanDbSwitcher.Tests"

if not test_project.exists():
    # No test project found — allow commit but warn
    print(f"Warning: test project not found at {test_project}", file=sys.stderr)
    sys.exit(0)

result = subprocess.run(
    ["dotnet", "test", str(test_project), "-v", "quiet"],
    capture_output=True,
    text=True,
    encoding="utf-8",
    errors="replace",
    cwd=str(project_dir),
)

if result.returncode != 0:
    output = ((result.stdout or "") + (result.stderr or "")).strip()
    # Limit output to avoid flooding Claude's context
    lines = output.splitlines()
    if len(lines) > 20:
        lines = lines[-20:]
    print("\n".join(lines), file=sys.stderr)
    print("\nTests failed. Fix tests before committing (TDD Law 2).", file=sys.stderr)
    sys.exit(2)

passed_line = next((l for l in (result.stdout or "").splitlines() if "passed" in l.lower()), "")
print(f"Tests passed. {passed_line}".strip())
sys.exit(0)
