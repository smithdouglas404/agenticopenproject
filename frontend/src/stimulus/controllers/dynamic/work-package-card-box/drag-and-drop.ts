export interface WorkPackageCardBoxItemData extends Record<string | symbol, unknown> {
  type:'work-package-card-box-item';
  dragType:string;
  itemId:string;
  itemIds:string[];
  sourceId:string;
}

export const workPackageCardBoxItemSelector = '[data-work-package-card-box-item-id]';

export function itemData({
  dragType,
  itemId,
  itemIds = [itemId],
  sourceId,
}:{
  dragType:string;
  itemId:string;
  itemIds?:string[];
  sourceId:string;
}):WorkPackageCardBoxItemData {
  return {
    type: 'work-package-card-box-item',
    dragType,
    itemId,
    itemIds,
    sourceId,
  };
}

export function isItemData(data:Record<string | symbol, unknown>):data is WorkPackageCardBoxItemData {
  return (
    data.type === 'work-package-card-box-item' &&
    typeof data.dragType === 'string' &&
    data.dragType.length > 0 &&
    typeof data.itemId === 'string' &&
    data.itemId.length > 0 &&
    Array.isArray(data.itemIds) &&
    data.itemIds.every((itemId) => typeof itemId === 'string' && itemId.length > 0) &&
    typeof data.sourceId === 'string' &&
    data.sourceId.length > 0
  );
}

export function resolveItemId(element:Element):string|null {
  return element.getAttribute('data-work-package-card-box-item-id');
}

export function selectedItemIdsFor(sourceItem:HTMLElement):string[] {
  if (sourceItem.getAttribute('data-work-package-card-box-selected') !== 'true') {
    return [resolveItemId(sourceItem)].filter((itemId):itemId is string => !!itemId);
  }

  const box = sourceItem.closest<HTMLElement>('[data-controller~="work-package-card-box"]');
  const selectedItems = Array.from(
    (box ?? sourceItem.ownerDocument).querySelectorAll<HTMLElement>(
      `${workPackageCardBoxItemSelector}[data-work-package-card-box-selected="true"]`,
    ),
  );
  const itemIds = selectedItems
    .map((item) => resolveItemId(item))
    .filter((itemId):itemId is string => !!itemId);

  return itemIds.length > 0 ? itemIds : [resolveItemId(sourceItem)].filter((itemId):itemId is string => !!itemId);
}
