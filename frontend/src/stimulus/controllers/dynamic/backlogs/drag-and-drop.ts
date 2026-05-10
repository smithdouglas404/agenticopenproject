import {
  attachClosestEdge,
  type Edge,
} from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge';
import { type Input } from '@atlaskit/pragmatic-drag-and-drop/types';
import {
  itemData as commonItemData,
  isItemData,
  resolveItemId,
  type WorkPackageCardBoxItemData,
  workPackageCardBoxItemSelector,
} from '../work-package-card-box/drag-and-drop';

export type ItemData = WorkPackageCardBoxItemData;
export { isItemData, resolveItemId };

const itemSelector = workPackageCardBoxItemSelector;
const listSelector = '[data-backlogs-target~="list"]';

export interface FallbackDropTarget {
  element:HTMLElement;
  data:Record<string | symbol, unknown>;
  isItem:boolean;
}

export function buildMoveFormData({
  targetId,
  previousItemId,
  sourceId,
  workPackageIds,
}:{
  targetId:string;
  previousItemId:string|null;
  sourceId?:string;
  workPackageIds?:string[];
}):FormData {
  const data = new FormData();

  data.append('target_id', targetId);
  data.append('prev_id', previousItemId ?? '');
  if (sourceId) {
    data.append('source_id', sourceId);
  }
  workPackageIds?.forEach((workPackageId) => data.append('work_package_ids[]', workPackageId));

  return data;
}

export function itemData(itemId:string):ItemData {
  return commonItemData({
    dragType: 'backlogs-item',
    itemId,
    sourceId: 'backlogs',
  });
}

export function resolveListTargetId(element:Element):string|null {
  return element.closest<HTMLElement>(listSelector)?.getAttribute('data-backlogs-target-id') ?? null;
}

export function resolveFallbackDropTarget({
  input,
  root,
  sourceElement,
  sourceItemIds = [],
}:{
  input:Input;
  root:HTMLElement;
  sourceElement?:HTMLElement;
  sourceItemIds?:string[];
}):FallbackDropTarget|null {
  const elementAtPoint = root.ownerDocument.elementFromPoint(input.clientX, input.clientY);
  const sourceItemIdSet = new Set(sourceItemIds);

  if (!(elementAtPoint instanceof HTMLElement) || !root.contains(elementAtPoint)) {
    return null;
  }

  const item = elementAtPoint.closest<HTMLElement>(itemSelector);
  if (item && item !== sourceElement && root.contains(item)) {
    const itemId = resolveItemId(item);

    if (itemId && !sourceItemIdSet.has(itemId)) {
      return {
        element: item,
        data: attachClosestEdge(commonItemData({
          dragType: 'backlogs-item',
          itemId,
          sourceId: resolveListTargetId(item) ?? '',
        }), {
          element: item,
          input,
          allowedEdges: ['top', 'bottom'],
        }),
        isItem: true,
      };
    }
  }

  const list = elementAtPoint.closest<HTMLElement>(listSelector);
  if (list && root.contains(list)) {
    return {
      element: list,
      data: { type: 'list', targetId: resolveListTargetId(list) },
      isItem: false,
    };
  }

  return null;
}

export function resolvePreviousItemId({
  sourceItemIds,
  targetItem,
  closestEdge,
}:{
  sourceItemIds:string[];
  targetItem:HTMLElement;
  closestEdge:Edge | null;
}):string|null {
  const sourceItemIdSet = new Set(sourceItemIds);
  const targetItemId = resolveItemId(targetItem);
  if (closestEdge === 'bottom' && targetItemId && !sourceItemIdSet.has(targetItemId)) {
    return targetItemId;
  }

  const targetRow = targetItem.closest('li');
  let row = targetRow?.previousElementSibling ?? null;

  while (row) {
    const item = row.querySelector<HTMLElement>(itemSelector);
    const itemId = item ? resolveItemId(item) : null;
    if (itemId && !sourceItemIdSet.has(itemId)) {
      return itemId;
    }

    row = row.previousElementSibling;
  }

  return null;
}

export function resolveListPreviousItemId({
  sourceItemIds,
  list,
}:{
  sourceItemIds:string[];
  list:Element;
}):string|null {
  const sourceItemIdSet = new Set(sourceItemIds);
  const rows = Array.from(list.querySelectorAll(':scope > li, :scope > ul > li')).reverse();

  for (const row of rows) {
    const item = row.querySelector<HTMLElement>(itemSelector);
    const itemId = item ? resolveItemId(item) : null;
    if (itemId && !sourceItemIdSet.has(itemId)) {
      return itemId;
    }
  }

  return null;
}
