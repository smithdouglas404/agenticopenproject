/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 * Copyright (C) 2006-2013 Jean-Philippe Lang
 * Copyright (C) 2010-2013 the ChiliProject Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * See COPYRIGHT and LICENSE files for more details.
 * ++
 */

import { useEffect } from 'react';
import type { BlockNoteEditor, InlineContentFromConfig } from '@blocknote/core';
import { wpBridge, makeInstanceId } from 'op-blocknote-extensions';
import type { InlineWpSize, BlockWpSize, WpSize } from 'op-blocknote-extensions';

type AnyEditor = BlockNoteEditor<any, any, any>;
type AnyInlineNode = InlineContentFromConfig<any, any>;

interface InlineWpNode {
  type:'inlineWorkPackage';
  props:{
    wpid:string;
    instanceId:string;
    size:InlineWpSize;
  };
  content: AnyInlineNode[];
}

const VALID_INLINE_SIZES:Set<InlineWpSize> = new Set(['xxs', 'xs', 's']);

function isInlineWpNode(node:unknown): node is InlineWpNode {
  if (typeof node !== 'object' || node === null) return false;

  const n = node as Record<string, unknown>;
  if (n['type'] !== 'inlineWorkPackage') return false;

  const props = n['props'];
  if (typeof props !== 'object' || props === null) return false;

  const p = props as Record<string, unknown>;
  return (
    typeof p['instanceId'] === 'string' &&
    typeof p['wpid'] === 'string' &&
    VALID_INLINE_SIZES.has(p['size'] as InlineWpSize)
  );
}

function asInlineNode(node:InlineWpNode):AnyInlineNode {
  return node as unknown as AnyInlineNode;
}

interface FoundInlineBlock {
  blockId:string;
  content:AnyInlineNode[];
  chip:InlineWpNode;
}

function findInlineChip(editor:AnyEditor, instanceId:string):FoundInlineBlock | null {
  let found: FoundInlineBlock | null = null;

  editor.forEachBlock((block) => {
    if (found) return false;

    const content = (block.content ?? []) as AnyInlineNode[];
    const chip = content.find(
      (node) => isInlineWpNode(node) && node.props.instanceId === instanceId
    ) as InlineWpNode | undefined;

    if (chip) {
      found = { blockId:block.id, content, chip };
      return false;
    }

    return true;
  });

  return found;
}

// The updater returns the updated node, or null to remove it.
// Returns found so the caller can use it without a second traversal.
function updateInlineChip(
  editor:AnyEditor,
  instanceId:string,
  updater:(chip:InlineWpNode) => InlineWpNode | null
): FoundInlineBlock | null {
  const found = findInlineChip(editor, instanceId);
  if (!found) return null;

  const updatedContent = found.content.reduce<AnyInlineNode[]>((acc, node) => {
    if (!isInlineWpNode(node) || node.props.instanceId !== instanceId) {
      acc.push(node);
      return acc;
    }
    const updated = updater(node);
    if (updated !== null) acc.push(asInlineNode(updated));
    return acc;
  }, []);

  editor.updateBlock(found.blockId, { content:updatedContent });
  return found;
}

function moveCursorAfter(editor:AnyEditor, blockId:string):void {
  requestAnimationFrame(() => {
    editor.focus();
    editor.setTextCursorPosition(blockId, 'end');

    const cursor = editor.getTextCursorPosition();
    if (!cursor?.nextBlock && cursor?.block) {
      editor.insertBlocks(
        [{ type:'paragraph', content:[] }],
        cursor.block.id,
        'after'
      );
    }

    const updated = editor.getTextCursorPosition();
    if (updated?.nextBlock) {
      editor.setTextCursorPosition(updated.nextBlock.id, 'start');
    }
  });
}

function handleResize(editor:AnyEditor, instanceId:string, size:WpSize):void {
  const isBlockSize = size === 'm' || size === 'l' || size === 'xl';

  if (isBlockSize) {
    handlePromoteToBlock(editor, instanceId, size as BlockWpSize);
    return;
  }

  updateInlineChip(editor, instanceId, (chip) => ({
    ...chip,
    props:{ ...chip.props, size:size as InlineWpSize },
  }));
}

function handleDelete(editor:AnyEditor, instanceId:string):void {
  updateInlineChip(editor, instanceId, () => null);
}

function handlePromoteToBlock(
  editor:AnyEditor,
  instanceId:string,
  size:BlockWpSize = 'm'
):void {
  const found = findInlineChip(editor, instanceId);
  if (!found) return;

  // wpid must be a positive integer
  const wpid = Number(found.chip.props.wpid);
  if (Number.isNaN(wpid) || wpid <= 0) return;

  updateInlineChip(editor, instanceId, () => null);

  const block = {
    type:'openProjectWorkPackage',
    props:{ wpid, initialized:true, size },
  } as Parameters<typeof editor.insertBlocks>[0][number];

  const [insertedBlock] = editor.insertBlocks(
    [block],
    found.blockId,
    'after'
  );

  if (insertedBlock?.id) {
    moveCursorAfter(editor, insertedBlock.id);
  }
}

function handleConvertToInline(
  editor:AnyEditor,
  wpid:number,
  size:InlineWpSize,
  blockId:string
):void {
  const block = editor.getBlock(blockId);
  if (!block) return;

  const instanceId = makeInstanceId();

  const paragraph = {
    type:'paragraph',
    content:[
      {
        type:'inlineWorkPackage',
        props:{ wpid:String(wpid), instanceId, size },
      },
    ],
  } as Parameters<typeof editor.insertBlocks>[0][number];

  const [insertedParagraph] = editor.insertBlocks(
    [paragraph],
    blockId,
    'before'
  );

  editor.removeBlocks([blockId]);

  requestAnimationFrame(() => {
    if (!insertedParagraph?.id) return;
    editor.focus();
    editor.setTextCursorPosition(insertedParagraph.id, 'end');
  });
}

// editor instance is stable for the lifetime of the component re-subscription only on editor replacement
export function useInlineWpEvents(editor: AnyEditor):void {
  useEffect(() => {
    const offResize = wpBridge.onResize(({ instanceId, size }) =>
      handleResize(editor, instanceId, size)
    );

    const offDelete = wpBridge.onDelete(({ instanceId }) =>
      handleDelete(editor, instanceId)
    );

    const offToInline = wpBridge.onConvertToInline(({ wpid, size, blockId }) =>
      handleConvertToInline(editor, wpid, size, blockId)
    );

    return () => {
      offResize();
      offDelete();
      offToInline();
    };
  }, [editor]);
}