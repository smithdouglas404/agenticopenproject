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

# Every locale file must carry the canonical GPL header. We strip whatever
# leading comment block / document marker the file happens to have and always
# emit this one, followed by a blank line and the `---` document start.
HEADER = """\
#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++
"""

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
    yaml.explicit_start = True  # emit the `---` document marker after the header

    with open(path, "r", encoding="utf-8") as f:
        data = yaml.load(f)

    if data is None:
        return

    walk(data)

    with open(path, "w", encoding="utf-8") as f:
        f.write(HEADER)
        f.write("\n")
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
