import React, { useEffect } from 'react';
import { monitorForElements } from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import { extractClosestEdge } from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge';
import { announce } from '@atlaskit/pragmatic-drag-and-drop-live-region';
import { useUpdateWorkPackage } from '../hooks/useUpdateWorkPackage';
import { useReorderWorkPackages } from '../hooks/useReorderWorkPackages';
import { moveWorkPackage } from '../dnd/move-work-package';
import { resolveBoardDropTarget } from '../dnd/board-drop';
import { extractBoardErrorMessage, showBoardError } from '../support/board-error';
import { BoardColumn } from './BoardColumn';
import { AddColumnAction } from './AddColumnAction';
import type { BoardGrid, ApiV3Filter } from '../api/types';

interface BoardCanvasProps {
  board:BoardGrid;
  filters:ApiV3Filter[];
}

function sortedWidgets(board:BoardGrid) {
  return [...board.widgets].sort((a, b) => a.startColumn - b.startColumn);
}

export function BoardCanvas({ board, filters }:BoardCanvasProps) {
  const updateWp = useUpdateWorkPackage();
  const reorder = useReorderWorkPackages();

  useEffect(() => {
    return monitorForElements({
      canMonitor: ({ source }) => source.data.type === 'card',
      onDragStart: ({ source }) => {
        const wpId = Number(source.data.workPackageId);
        if (!Number.isFinite(wpId)) {
          return;
        }

        announce(`Picked up card #${wpId}. Use arrow keys to move.`);
      },
      onDrop: ({ source, location }) => {
        const target = location.current.dropTargets[0];
        const wpId = source.data.workPackageId as number;
        const fromIndex = source.data.index as number;
        const sourceQueryId =
          typeof source.data.sourceQueryId === 'string'
            ? source.data.sourceQueryId
            : typeof source.data.sourceQueryId === 'number'
              ? String(source.data.sourceQueryId)
              : '';
        const sourceOrder = source.data.order as string[];
        const sourcePositions = source.data.positions as Record<string, number>;
        const lockVersion = source.data.lockVersion as number;

        if (!target) {
          announce(`Card #${wpId} dropped. No changes made.`);
          return;
        }

        const resolvedTarget = resolveBoardDropTarget(
          target.data as Record<string, unknown>,
          extractClosestEdge(target.data),
        );

        if (
          !sourceQueryId
          || !Array.isArray(sourceOrder)
          || typeof sourcePositions !== 'object'
          || sourcePositions === null
          || !resolvedTarget
          || typeof fromIndex !== 'number'
          || !wpId
        ) {
          return;
        }

        void moveWorkPackage({
          reorderWorkPackages: reorder.mutateAsync,
          updateWorkPackage: updateWp.mutateAsync,
        }, {
          board,
          wpId,
          lockVersion,
          source: {
            queryId: sourceQueryId,
            order: sourceOrder,
            positions: sourcePositions,
          },
          target: resolvedTarget,
          fromIndex,
        }).then(() => {
          if (sourceQueryId === resolvedTarget.queryId) {
            announce(`Card #${wpId} reordered.`);
          } else {
            announce(`Card #${wpId} moved to a different column.`);
          }
        }).catch((error:unknown) => {
          const message = extractBoardErrorMessage(error, `Card #${wpId} could not be moved.`);

          void showBoardError(error, message);
          announce(message);
        });
      },
    });
  }, [board, updateWp, reorder]);

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
      {widgets.map((widget, index) => (
        <BoardColumn
          key={`${widget.options.queryId ?? 'widget'}-${widget.startColumn}-${index}`}
          widget={widget}
          filters={filters}
        />
      ))}
      <AddColumnAction />
    </div>
  );
}
