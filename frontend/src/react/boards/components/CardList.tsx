import React, { useRef, useEffect, useState } from 'react';
import { Box } from '@primer/react';
import {
  dropTargetForElements,
} from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import {
  attachClosestEdge,
  extractClosestEdge,
} from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge';
import { BoardCard } from './BoardCard';
import { DropIndicator } from './DropIndicator';
import type { WorkPackage } from '../api/types';

interface CardListProps {
  workPackages: WorkPackage[];
  queryId: string;
  canDrop: boolean;
  actionFilterValue?: string;
}

interface DropState {
  index: number;
  edge: 'top' | 'bottom';
}

export function CardList({ workPackages, queryId, canDrop, actionFilterValue }: CardListProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [dropState, setDropState] = useState<DropState | null>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el || !canDrop) return;

    return dropTargetForElements({
      element: el,
      getData: ({ input, element }) => {
        return attachClosestEdge(
          { type: 'card-list', queryId, actionFilterValue },
          { input, element, allowedEdges: ['top', 'bottom'] },
        );
      },
      canDrop: ({ source }) => source.data.type === 'card',
      onDrag: ({ self }) => {
        const edge = extractClosestEdge(self.data);
        if (edge === 'top' || edge === 'bottom') {
          setDropState({ index: 0, edge });
        }
      },
      onDragLeave: () => setDropState(null),
      onDrop: () => setDropState(null),
    });
  }, [queryId, canDrop, actionFilterValue]);

  return (
    <Box
      ref={ref}
      sx={{
        display: 'flex',
        flexDirection: 'column',
        gap: 2,
        minHeight: '100px',
        p: 2,
        flexGrow: 1,
        overflowY: 'auto',
      }}
    >
      {workPackages.map((wp, index) => (
        <Box key={wp.id} sx={{ position: 'relative' }}>
          {dropState?.index === index && dropState.edge === 'top' && (
            <DropIndicator edge="top" />
          )}
          <BoardCard
            workPackage={wp}
            queryId={queryId}
            index={index}
            isDragDisabled={!canDrop}
          />
          {dropState?.index === index && dropState.edge === 'bottom' && (
            <DropIndicator edge="bottom" />
          )}
        </Box>
      ))}

      {workPackages.length === 0 && (
        <Box
          sx={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'fg.muted',
            fontSize: 1,
            py: 4,
          }}
        >
          No work packages
        </Box>
      )}
    </Box>
  );
}
