import React, { useEffect } from 'react';
import { monitorForElements } from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import { announce } from '@atlaskit/pragmatic-drag-and-drop-live-region';
import { useBoardContext } from '../context/BoardContext';
import { useUpdateWorkPackage } from '../hooks/useUpdateWorkPackage';
import { useReorderWorkPackages } from '../hooks/useReorderWorkPackages';
import { BoardColumn } from './BoardColumn';
import { AddColumnAction } from './AddColumnAction';
import type { BoardGrid, ApiV3Filter } from '../api/types';

interface BoardCanvasProps {
  board: BoardGrid;
  filters: ApiV3Filter[];
}

function sortedWidgets(board: BoardGrid) {
  return [...board.widgets].sort((a, b) => a.startColumn - b.startColumn);
}

export function BoardCanvas({ board, filters }: BoardCanvasProps) {
  const { actionAttribute } = useBoardContext();
  const updateWp = useUpdateWorkPackage();
  const reorder = useReorderWorkPackages();

  useEffect(() => {
    return monitorForElements({
      canMonitor: ({ source }) => source.data.type === 'card',
      onDragStart: ({ source }) => {
        const wpId = source.data.workPackageId;
        announce(`Picked up card #${wpId}. Use arrow keys to move.`);
      },
      onDrop: ({ source, location }) => {
        const target = location.current.dropTargets[0];
        const wpId = source.data.workPackageId as number;

        if (!target) {
          announce(`Card #${wpId} dropped. No changes made.`);
          return;
        }

        const sourceQueryId = source.data.sourceQueryId as string;
        const targetQueryId = target.data.queryId as string;
        const lockVersion = source.data.lockVersion as number;

        if (!sourceQueryId || !targetQueryId || !wpId) return;

        if (sourceQueryId !== targetQueryId && actionAttribute) {
          const targetValue = target.data.actionFilterValue as string;
          if (targetValue) {
            announce(`Card #${wpId} moved to a different column.`);
            updateWp.mutate({
              wpId,
              lockVersion,
              attributes: {
                _links: {
                  [actionAttribute]: { href: `/api/v3/statuses/${targetValue}` },
                },
              },
              sourceQueryId,
              targetQueryId,
            });
          }
        } else {
          announce(`Card #${wpId} reordered.`);
          reorder.mutate({ queryId: targetQueryId, delta: { [wpId]: 0 } });
        }
      },
    });
  }, [actionAttribute, updateWp, reorder]);

  const widgets = sortedWidgets(board);

  return (
    <div
      style={{
        display: 'flex',
        gap: '12px',
        overflowX: 'auto',
        padding: '12px',
        flexGrow: 1,
        alignItems: 'flex-start',
      }}
    >
      {widgets.map((widget) => (
        <BoardColumn key={widget.startColumn} widget={widget} filters={filters} />
      ))}
      <AddColumnAction />
    </div>
  );
}
