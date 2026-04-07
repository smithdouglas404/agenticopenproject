import type { BoardGrid } from '../api/types';
import { isReactBoardSupported } from '../support/supported-board';
import { buildInsertDelta, buildRemoveDelta } from './query-order';
import type { BoardDropTarget, BoardQueryState } from './board-drop';

interface UpdateWorkPackageArgs {
  wpId:number;
  lockVersion:number;
  attributes:Record<string, unknown>;
  sourceQueryId:string;
  targetQueryId:string;
}

interface ReorderWorkPackagesArgs {
  queryId:string;
  delta:Record<string, number>;
}

interface MoveWorkPackageDependencies {
  reorderWorkPackages(args:ReorderWorkPackagesArgs):Promise<unknown>;
  updateWorkPackage(args:UpdateWorkPackageArgs):Promise<unknown>;
}

interface MoveWorkPackageArgs {
  board:BoardGrid;
  wpId:number;
  lockVersion:number;
  source:BoardQueryState;
  target:BoardDropTarget;
  fromIndex:number;
}

export async function moveWorkPackage(
  dependencies:MoveWorkPackageDependencies,
  args:MoveWorkPackageArgs,
):Promise<void> {
  if (!isReactBoardSupported(args.board)) {
    throw new Error('Unsupported board type');
  }

  const wpId = String(args.wpId);
  const sameList = args.source.queryId === args.target.queryId;

  if (args.board.options.type === 'action' && args.board.options.attribute === 'status' && !sameList) {
    if (!args.target.actionFilterValue) {
      throw new Error('Missing target status');
    }

    await dependencies.updateWorkPackage({
      wpId: args.wpId,
      lockVersion: args.lockVersion,
      attributes: {
        _links: {
          status: { href: `/api/v3/statuses/${args.target.actionFilterValue}` },
        },
      },
      sourceQueryId: args.source.queryId,
      targetQueryId: args.target.queryId,
    });
  }

  if (sameList) {
    await dependencies.reorderWorkPackages({
      queryId: args.source.queryId,
      delta: buildInsertDelta({
        list: args.source,
        wpId,
        toIndex: args.target.index,
        fromIndex: args.fromIndex,
      }),
    });

    return;
  }

  await dependencies.reorderWorkPackages({
    queryId: args.source.queryId,
    delta: buildRemoveDelta(wpId),
  });

  await dependencies.reorderWorkPackages({
    queryId: args.target.queryId,
    delta: buildInsertDelta({
      list: args.target,
      wpId,
      toIndex: args.target.index,
    }),
  });
}
