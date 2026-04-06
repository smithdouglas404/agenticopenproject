import type { Edge } from '@atlaskit/pragmatic-drag-and-drop-hitbox/types';
import type { QueryListState } from './query-order';

export interface BoardQueryState extends QueryListState {
  queryId:string;
  actionFilterValue?:string;
}

export interface BoardDropTarget extends BoardQueryState {
  index:number;
}

export function resolveBoardDropTarget(
  data:Partial<BoardDropTarget>,
  edge:Edge | null,
):BoardDropTarget | null {
  if (
    typeof data.queryId !== 'string'
    || !Array.isArray(data.order)
    || typeof data.positions !== 'object'
    || data.positions === null
  ) {
    return null;
  }

  const baseIndex = typeof data.index === 'number' ? data.index : 0;

  return {
    queryId: data.queryId,
    actionFilterValue: data.actionFilterValue,
    order: data.order,
    positions: data.positions,
    index: edge === 'bottom' ? baseIndex + 1 : baseIndex,
  };
}
