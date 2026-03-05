# Python Toolchain Reference

Detailed configuration, patterns, and examples for the python-expert skill.

---

## uv Project Setup

```toml
# pyproject.toml — complete starter configuration
[project]
name = "my-project"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[tool.uv]
dev-dependencies = ["ruff>=0.4", "mypy>=1.10", "pytest>=8"]
```

Bootstrap commands:
```bash
uv init my-project
cd my-project
uv add --dev ruff mypy pytest
uv run pytest          # run tests without activating venv
uv lock                # generate uv.lock — commit to VCS
```

---

## ruff Configuration

```toml
[tool.ruff]
line-length = 88
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP", "RUF"]
ignore = ["E501"]   # formatter handles line length

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["S101"]   # allow assert in tests
```

Run lint and format:
```bash
ruff check --fix .      # fix auto-fixable violations
ruff format .           # format all files
```

---

## mypy Strict Setup

```toml
[tool.mypy]
python_version = "3.11"
strict = true

[[tool.mypy.overrides]]
module = ["pandas.*", "boto3.*", "botocore.*"]
ignore_missing_imports = true
```

Incremental migration path for legacy code:
1. Start with `disallow_untyped_defs = true` only
2. Add `warn_return_any = true`
3. Add `disallow_any_generics = true`
4. Enable full `strict = true` once those pass

---

## pytest Fixture Patterns

### Session-scoped engine (expensive resource)

```python
# conftest.py
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

@pytest.fixture(scope="session")
def db_engine():
    engine = create_engine("postgresql://localhost/test_db")
    yield engine
    engine.dispose()

@pytest.fixture(scope="function")
def db_session(db_engine):
    """Each test runs in a rolled-back transaction."""
    with db_engine.connect() as conn:
        transaction = conn.begin()
        session = Session(bind=conn)
        yield session
        session.close()
        transaction.rollback()
```

### Parametrize with readable IDs

```python
import pytest

@pytest.mark.parametrize(
    "input,expected",
    [
        pytest.param("hello", 5, id="normal-string"),
        pytest.param("", 0, id="empty-string"),
        pytest.param("  ", 2, id="whitespace"),
    ],
)
def test_length(input: str, expected: int) -> None:
    assert len(input) == expected
```

---

## Pydantic v2 Patterns

```python
from pydantic import BaseModel, field_validator, model_validator
from datetime import datetime

class OrderRequest(BaseModel):
    item_id: str
    quantity: int
    ship_by: datetime | None = None

    @field_validator("quantity")
    @classmethod
    def quantity_positive(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("quantity must be positive")
        return v

    @model_validator(mode="after")
    def ship_by_future(self) -> "OrderRequest":
        if self.ship_by and self.ship_by < datetime.now():
            raise ValueError("ship_by must be in the future")
        return self

# Serialization
order = OrderRequest(item_id="abc", quantity=3)
order.model_dump()           # → dict
order.model_dump_json()      # → JSON string
OrderRequest.model_validate({"item_id": "abc", "quantity": 3})
```

---

## pathlib Patterns

```python
from pathlib import Path

# Reading and writing
config_path = Path.home() / ".config" / "myapp" / "settings.json"
config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text('{"theme": "dark"}')
content = config_path.read_text()

# Traversal
project_root = Path(__file__).parent.parent
for py_file in project_root.rglob("*.py"):
    print(py_file.relative_to(project_root))

# Never use os.path
# BAD:  os.path.join(os.path.expanduser("~"), ".config", "myapp")
# GOOD: Path.home() / ".config" / "myapp"
```

---

## match/case Patterns

```python
from dataclasses import dataclass

@dataclass
class Point:
    x: float
    y: float

def classify(obj: object) -> str:
    match obj:
        case Point(x=0, y=0):
            return "origin"
        case Point(x=0, y=y):
            return f"y-axis at {y}"
        case Point(x=x, y=0):
            return f"x-axis at {x}"
        case Point(x=x, y=y):
            return f"point ({x}, {y})"
        case {"action": action, "payload": payload}:
            return f"command {action!r} with {payload}"
        case _:
            return "unknown"
```

Prefer `match/case` over `isinstance` chains when handling 3+ variants of structured data (Python 3.10+).

---

## Context Manager Patterns

```python
from contextlib import contextmanager, suppress
from pathlib import Path

# Always: with for file I/O
with Path("data.txt").open() as f:
    content = f.read()

# Custom context manager via decorator
@contextmanager
def managed_transaction(session):
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise

# Suppress specific exceptions
with suppress(FileNotFoundError):
    Path("optional.txt").unlink()

# NEVER: open without context manager
# BAD:  f = open("data.txt"); content = f.read(); f.close()
# GOOD: with open("data.txt") as f: content = f.read()
```

---

## Troubleshooting

### Error: mypy "Module has no attribute" or "Cannot find implementation or library stub"

Cause: Third-party library has no type stubs or `py.typed` marker.

Solution:
1. Check if stubs exist: `uv add --dev types-requests` (for `requests`), `pandas-stubs`, etc.
2. If no stubs available, add an override:
   ```toml
   [[tool.mypy.overrides]]
   module = "library_name.*"
   ignore_missing_imports = true
   ```
3. For your own packages: add an empty `py.typed` marker file at the package root.

---

### Error: Mutable default argument causes shared state between calls

Cause: `def f(items=[])` — the list is created once at function definition and shared across all calls.

Solution:
```python
# BAD
def append_item(item: str, items: list[str] = []) -> list[str]:
    items.append(item)
    return items

# GOOD
def append_item(item: str, items: list[str] | None = None) -> list[str]:
    if items is None:
        items = []
    items.append(item)
    return items
```

---

### Error: ruff and existing formatter (black/isort) produce conflicting changes

Cause: Running both ruff and black/isort creates formatting conflicts because both manage the same rules.

Solution:
1. Remove black and isort from dependencies: `uv remove black isort`
2. ruff replaces both — `ruff check --fix` for linting, `ruff format` for formatting
3. Consolidate all config in `pyproject.toml` under `[tool.ruff]`
4. Delete `.flake8`, `setup.cfg` lint sections, and `.isort.cfg` if they exist
