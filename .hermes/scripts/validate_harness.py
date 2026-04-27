#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import json
import sys


@dataclass
class ValidationResult:
    errors: list[str] = field(default_factory=list)
    validated_examples: int = 0

    @property
    def ok(self) -> bool:
        return not self.errors


SCHEMA_BY_PREFIX = {
    "run": "run.schema.json",
    "observation": "observation.schema.json",
    "decision": "decision.schema.json",
    "verification": "verification.schema.json",
}


def _load_json(path: Path, result: ValidationResult):
    try:
        return json.loads(path.read_text())
    except Exception as exc:  # noqa: BLE001 - CLI validator should report exact path
        result.errors.append(f"{path}: invalid JSON: {exc}")
        return None


def _schema_for_example(example_path: Path, schemas_dir: Path, result: ValidationResult):
    name = example_path.name
    for prefix, schema_name in SCHEMA_BY_PREFIX.items():
        if name.startswith(prefix + "."):
            schema = _load_json(schemas_dir / schema_name, result)
            return schema
    result.errors.append(f"{example_path}: no matching schema prefix")
    return None


def _validate_type(value, expected):
    if isinstance(expected, list):
        return any(_validate_type(value, item) for item in expected)
    if expected == "string":
        return isinstance(value, str)
    if expected == "array":
        return isinstance(value, list)
    if expected == "object":
        return isinstance(value, dict)
    if expected == "null":
        return value is None
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    return True


def _validate_against_schema(data: dict, schema: dict, path: Path) -> list[str]:
    errors: list[str] = []
    if schema.get("type") == "object" and not isinstance(data, dict):
        return [f"{path}: expected object"]

    required = schema.get("required", [])
    for key in required:
        if key not in data:
            errors.append(f"{path}: missing required field {key}")

    properties = schema.get("properties", {})
    for key, value in data.items():
        if schema.get("additionalProperties") is False and key not in properties:
            errors.append(f"{path}: unexpected field {key}")
            continue
        prop = properties.get(key, {})
        if "type" in prop and not _validate_type(value, prop["type"]):
            errors.append(f"{path}: field {key} has wrong type")
        if "enum" in prop and value not in prop["enum"]:
            errors.append(f"{path}: field {key} value {value!r} not in enum")
        if prop.get("type") == "array" and isinstance(value, list):
            item_type = prop.get("items", {}).get("type")
            if item_type:
                for index, item in enumerate(value):
                    if not _validate_type(item, item_type):
                        errors.append(f"{path}: field {key}[{index}] has wrong type")
    return errors


def validate_harness(hermes_dir: Path | str = Path(".hermes")) -> ValidationResult:
    hermes_dir = Path(hermes_dir)
    result = ValidationResult()
    schemas_dir = hermes_dir / "schemas"
    examples_dir = hermes_dir / "examples"

    required_schemas = sorted(SCHEMA_BY_PREFIX.values())
    for schema_name in required_schemas:
        schema_path = schemas_dir / schema_name
        schema = _load_json(schema_path, result)
        if schema is None:
            continue
        for key in ("title", "type", "required", "properties"):
            if key not in schema:
                result.errors.append(f"{schema_path}: missing schema key {key}")

    for example_path in sorted(examples_dir.glob("*.json")):
        data = _load_json(example_path, result)
        schema = _schema_for_example(example_path, schemas_dir, result)
        if data is None or schema is None:
            continue
        result.errors.extend(_validate_against_schema(data, schema, example_path))
        result.validated_examples += 1

    return result


def main(argv: list[str] | None = None) -> int:
    argv = argv or sys.argv[1:]
    hermes_dir = Path(argv[0]) if argv else Path(".hermes")
    result = validate_harness(hermes_dir)
    if result.ok:
        print(f"PASS validated_examples={result.validated_examples}")
        return 0
    for error in result.errors:
        print(f"ERROR {error}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
