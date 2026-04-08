//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { Decoration, DecorationSet } from '@tiptap/pm/view';
import type { Node as PmNode } from '@tiptap/pm/model';
import { isHrefExternal } from 'core-stimulus/helpers/external-link-helpers';

const pluginKey = new PluginKey('externalLinkA11y');

function buildDecorations(doc:PmNode):DecorationSet {
  const decorations:Decoration[] = [];
  doc.descendants((node, pos) => {
    for (const mark of node.marks) {
      if (mark.type.name === 'link' && isHrefExternal(String(mark.attrs.href ?? ''))) {
        decorations.push(
          Decoration.inline(pos, pos + node.nodeSize, {
            'aria-describedby': 'open-blank-target-link-description',
          }),
        );
        break;
      }
    }
  });
  return DecorationSet.create(doc, decorations);
}

/**
 * TipTap extension that adds `aria-describedby` to external links inside the
 * editor via ProseMirror Decorations.
 *
 * Decorations add DOM attributes without modifying the document model, so
 * ProseMirror does not re-render and there is no risk of infinite loops (the
 * reason direct DOM mutation was previously avoided for this attribute).
 *
 * Uses the `state.init/apply` pattern: decorations are rebuilt only when the
 * document changes, and cheaply remapped via `DecorationSet.map()` otherwise
 * (e.g. on selection changes or non-doc transactions).
 *
 * The referenced description element (`open-blank-target-link-description`) is
 * a screen-reader-only `<span>` that tells assistive-technology users the link
 * opens in a new tab. It lives in the main layout (`base.html.erb`) and is
 * cloned into the BlockNote shadow DOM by `block-note-element.ts`.
 */
export const ExternalLinkA11yExtension = Extension.create({
  name: 'externalLinkA11y',

  addProseMirrorPlugins() {
    return [
      new Plugin({
        key: pluginKey,
        state: {
          init(_, { doc }) {
            return buildDecorations(doc);
          },
          apply(tr, oldDecos) {
            if (tr.docChanged) {
              return buildDecorations(tr.doc);
            }
            return oldDecos.map(tr.mapping, tr.doc);
          },
        },
        props: {
          decorations(state) {
            return pluginKey.getState(state) as DecorationSet;
          },
        },
      }),
    ];
  },
});
