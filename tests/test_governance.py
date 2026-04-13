from __future__ import annotations

import ast
import unittest
from pathlib import Path

from tests.test_support import REPO_ROOT


class GovernanceTests(unittest.TestCase):
    def iter_python_files(self) -> list[Path]:
        python_files: list[Path] = []
        for subtree in ("scripts", "tests"):
            python_files.extend(sorted((REPO_ROOT / subtree).rglob("*.py")))
        return python_files

    def iter_shell_files(self) -> list[Path]:
        shell_files = sorted(REPO_ROOT.glob("*.sh"))
        shell_files.extend(sorted((REPO_ROOT / "scripts").rglob("*.sh")))
        return shell_files

    def annotation_contains_pep604_union(self, node: ast.AST) -> bool:
        return any(
            isinstance(child, ast.BinOp) and isinstance(child.op, ast.BitOr)
            for child in ast.walk(node)
        )

    def iter_annotation_nodes(self, tree: ast.AST) -> list[ast.AST]:
        annotations: list[ast.AST] = []
        for node in ast.walk(tree):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                arguments = [
                    *node.args.posonlyargs,
                    *node.args.args,
                    *node.args.kwonlyargs,
                ]
                if node.args.vararg is not None:
                    arguments.append(node.args.vararg)
                if node.args.kwarg is not None:
                    arguments.append(node.args.kwarg)
                for argument in arguments:
                    if argument.annotation is not None:
                        annotations.append(argument.annotation)
                if node.returns is not None:
                    annotations.append(node.returns)
            elif isinstance(node, ast.AnnAssign):
                annotations.append(node.annotation)
        return annotations

    def test_repo_has_local_agents_file(self) -> None:
        self.assertTrue((REPO_ROOT / "AGENTS.md").is_file())

    def test_python_files_do_not_use_write_text_newline_keyword(self) -> None:
        offenders: list[str] = []

        for path in self.iter_python_files():
            tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
            for node in ast.walk(tree):
                if not isinstance(node, ast.Call):
                    continue
                func = node.func
                if not isinstance(func, ast.Attribute) or func.attr != "write_text":
                    continue
                if any(keyword.arg == "newline" for keyword in node.keywords):
                    offenders.append(path.relative_to(REPO_ROOT).as_posix())
                    break

        self.assertEqual([], offenders)

    def test_python_files_do_not_use_pep604_union_annotations(self) -> None:
        offenders: list[str] = []

        for path in self.iter_python_files():
            tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
            for annotation in self.iter_annotation_nodes(tree):
                if self.annotation_contains_pep604_union(annotation):
                    offenders.append(path.relative_to(REPO_ROOT).as_posix())
                    break

        self.assertEqual([], offenders)

    def test_shell_entrypoints_do_not_hardcode_python3_execution(self) -> None:
        offenders: list[str] = []
        allowlist = {
            (REPO_ROOT / "scripts" / "setup_env.sh").resolve(),
            (REPO_ROOT / "scripts" / "lib" / "runtime_compat.sh").resolve(),
        }

        for path in self.iter_shell_files():
            if path.resolve() in allowlist:
                continue
            for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
                stripped = line.strip()
                if "python3" not in stripped:
                    continue
                if stripped.startswith("#"):
                    continue
                offenders.append(f"{path.relative_to(REPO_ROOT).as_posix()}:{lineno}")
                break

        self.assertEqual([], offenders)


if __name__ == "__main__":
    unittest.main()
