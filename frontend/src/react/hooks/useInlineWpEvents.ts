import { useEffect } from "react";
import type { BlockNoteEditor, InlineContentFromConfig } from "@blocknote/core";
import type { InlineWpSize } from "op-blocknote-extensions";

// BlockNote requires all three schema generics (blockSchema, inlineContentSchema,
// styleSchema) to be passed explicitly. Since this hook is schema-agnostic by design
// it works with any editor that has inlineWorkPackage registered we use
// `any` here rather than threading the concrete schema type through as a generic.
type AnyEditor = BlockNoteEditor<any, any, any>;
type AnyInlineNode = InlineContentFromConfig<any, any> & {
  type: string;
  props?: Record<string, unknown>;
};

interface ResizeEventDetail {
  instanceId: string;
  wpid: number;
  size: InlineWpSize;
}

interface DeleteEventDetail {
  instanceId: string;
  wpid: number;
}

interface PromoteToBlockDetail {
  instanceId: string;
}

interface ConvertToInlineDetail {
  wpid: number;
  size: InlineWpSize;
}


// Walks all blocks (including nested) and returns the first one that contains
// an `inlineWorkPackage` chip matching `instanceId`.
// Also surfaces the chip's `wpid` string to avoid a second traversal.

function findBlockByInstanceId(
  editor: AnyEditor,
  instanceId: string
): { blockId: string; content: AnyInlineNode[]; wpid: string | undefined } | null {
  let found: { blockId: string; content: AnyInlineNode[]; wpid: string | undefined } | null = null;

  editor.forEachBlock((block) => {
    if (found) return false;

    const content = (block.content ?? []) as AnyInlineNode[];
    const chip = content.find(
      (node) =>
        node.type === "inlineWorkPackage" &&
        node.props?.instanceId === instanceId
    );

    if (chip) {
      found = { blockId: block.id, content, wpid: chip.props?.wpid as string | undefined };
      return false;
    }

    return true;
  });

  return found;
}


// Finds the block-level `openProjectWorkPackage` block whose `wpid` matches.
// Used when converting a block card to an inline chip.

function findBlockWpBlock(
  editor: AnyEditor,
  wpid: number
): { blockId: string } | null {
  let found: { blockId: string } | null = null;

  editor.forEachBlock((block) => {
    if (found) return false;

    if (
      block.type === "openProjectWorkPackage" &&
      (block as any).props?.wpid === wpid
    ) {
      found = { blockId: block.id };
      return false;
    }

    return true;
  });

  return found;
}

export function useInlineWpEvents(editor: AnyEditor): void {
  useEffect(() => {
    // Resize
    const handleResize = (e: Event): void => {
      const { instanceId, size } = (e as CustomEvent<ResizeEventDetail>).detail;

      // "M" means promote to a full block card
      if (size === "m") {
        document.dispatchEvent(
          new CustomEvent("op-inline-wp-promote-to-block", { detail: { instanceId } })
        );
        return;
      }

      const found = findBlockByInstanceId(editor, instanceId);
      if (!found) return;

      const updatedContent = found.content.map((node) => {
        if (node.type === "inlineWorkPackage" && node.props?.instanceId === instanceId) {
          return { ...node, props: { ...node.props, size } };
        }
        return node;
      });

      editor.updateBlock(found.blockId, { content: updatedContent } as any);
    };

    // Delete
    const handleDelete = (e: Event): void => {
      const { instanceId } = (e as CustomEvent<DeleteEventDetail>).detail;

      const found = findBlockByInstanceId(editor, instanceId);
      if (!found) return;

      const updatedContent = found.content.filter(
        (node) =>
          !(node.type === "inlineWorkPackage" && node.props?.instanceId === instanceId)
      );

      editor.updateBlock(found.blockId, { content: updatedContent } as any);
    };

    // Promote inline chip full block-level WP card
    const handlePromoteToBlock = (e: Event): void => {
      const { instanceId } = (e as CustomEvent<PromoteToBlockDetail>).detail;

      const found = findBlockByInstanceId(editor, instanceId);
      if (!found) return;

      const wpid = found.wpid ? Number(found.wpid) : undefined;
      if (!wpid) return;

      // Remove the chip from its inline block
      const updatedContent = found.content.filter(
        (node) =>
          !(node.type === "inlineWorkPackage" && node.props?.instanceId === instanceId)
      );
      editor.updateBlock(found.blockId, { content: updatedContent } as any);

      // Insert openProjectWorkPackage block right after
      editor.insertBlocks(
        [{ type: "openProjectWorkPackage", props: { wpid, initialized: true } } as any],
        found.blockId,
        "after"
      );
    };

    // Convert block card inline chip
    const handleConvertToInline = (e: Event): void => {
      const { wpid, size } = (e as CustomEvent<ConvertToInlineDetail>).detail;

      const found = findBlockWpBlock(editor, wpid);
      if (!found) return;

      // Generate a fresh instanceId for the new inline chip
      const instanceId = `iid-${Date.now()}-${Math.random().toString(36).slice(2)}`;

      // Insert a new paragraph with the inline chip BEFORE the block card.
      // We use "before" so the block card can be safely removed afterwards
      // without the cursor jumping unexpectedly.
      editor.insertBlocks(
        [
          {
            type: "paragraph",
            content: [
              {
                type: "inlineWorkPackage",
                props: { wpid: String(wpid), instanceId, size },
              },
            ],
          } as any,
        ],
        found.blockId,
        "before"
      );

      // Remove the block-level card
      editor.removeBlocks([found.blockId]);
    };

    document.addEventListener("op-inline-wp-resize", handleResize);
    document.addEventListener("op-inline-wp-delete", handleDelete);
    document.addEventListener("op-inline-wp-promote-to-block", handlePromoteToBlock);
    document.addEventListener("op-block-wp-to-inline", handleConvertToInline);

    return () => {
      document.removeEventListener("op-inline-wp-resize", handleResize);
      document.removeEventListener("op-inline-wp-delete", handleDelete);
      document.removeEventListener("op-inline-wp-promote-to-block", handlePromoteToBlock);
      document.removeEventListener("op-block-wp-to-inline", handleConvertToInline);
    };
  }, [editor]);
}