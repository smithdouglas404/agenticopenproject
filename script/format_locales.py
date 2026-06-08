# /// script
# dependencies = ["ruamel.yaml"]
# ///

import sys
from ruamel.yaml import YAML
from ruamel.yaml.comments import CommentedMap
from ruamel.yaml.scalarstring import (
    FoldedScalarString, LiteralScalarString,
    SingleQuotedScalarString, DoubleQuotedScalarString,
)

WIDTH = 120

def maybe_fold(value, indent):
    if isinstance(value, (LiteralScalarString, SingleQuotedScalarString, DoubleQuotedScalarString)):
        return value
    if not isinstance(value, str):
        return value
    already_folded = isinstance(value, FoldedScalarString)
    text = " ".join(value.split())                 # collapse to one logical line
    if len(text) + indent <= WIDTH and not already_folded:
        return value
    return FoldedScalarString(text)                # ruamel soft-wraps at WIDTH

def walk(node, indent=0):
    if isinstance(node, CommentedMap):
        for k in sorted(node.keys(), key=str):
            node.move_to_end(k)
            v = node[k]
            if isinstance(v, (CommentedMap, list)):
                walk(v, indent + 2)
            else:
                node[k] = maybe_fold(v, indent + 2 + len(str(k)) + 2)
    elif isinstance(node, list):
        for item in node:
            walk(item, indent + 2)

def format_file(path):
    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.width = WIDTH
    yaml.indent(mapping=2, sequence=4, offset=2)

    with open(path, "r", encoding="utf-8") as f:
        raw = f.read()

    yaml.explicit_start = raw.lstrip().startswith("---")
    data = yaml.load(raw)

    if data is None:
        return

    walk(data)

    with open(path, "w", encoding="utf-8") as f:
        yaml.dump(data, f)

def main(argv):
    if not argv:
        print("usage: format_locales.py <file.yml> [<file.yml> ...]", file=sys.stderr)
        return 1

    for path in argv:
        print(f"formatting {path}...")
        format_file(path)
        print(f"formatted {path}")

    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
