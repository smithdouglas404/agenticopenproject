import { buildDelta } from 'core-app/shared/helpers/drag-and-drop/reorder-delta-builder';
import type { QueryOrder } from 'core-app/core/apiv3/endpoints/queries/apiv3-query-order';

export type { QueryOrder } from 'core-app/core/apiv3/endpoints/queries/apiv3-query-order';

export interface QueryListState {
  order:string[];
  positions:QueryOrder;
}

export function buildInsertDelta(args:{
  list:QueryListState;
  wpId:string;
  toIndex:number;
  fromIndex?:number | null;
}):QueryOrder {
  const nextOrder = [...args.list.order];

  if (args.fromIndex !== null && args.fromIndex !== undefined) {
    nextOrder.splice(args.fromIndex, 1);
  }

  nextOrder.splice(args.toIndex, 0, args.wpId);

  return buildDelta(
    nextOrder,
    args.list.positions,
    args.wpId,
    args.toIndex,
    args.fromIndex ?? null,
  );
}

export function buildRemoveDelta(wpId:string):QueryOrder {
  return { [wpId]: -1 };
}
