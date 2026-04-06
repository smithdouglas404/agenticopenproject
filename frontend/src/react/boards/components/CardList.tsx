import React, { useRef, useEffect, useState } from 'react';
import {
  dropTargetForElements,
} from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import {
  attachClosestEdge,
  extractClosestEdge,
} from '@atlaskit/pragmatic-drag-and-drop-hitbox/closest-edge';
import { BoardCard } from './BoardCard';
import { DropIndicator } from './DropIndicator';
import type { QueryOrder } from '../dnd/query-order';
import type { WorkPackage } from '../api/types';

interface CardListProps {
  workPackages:WorkPackage[];
  queryId:string;
  order:string[];
  positions:QueryOrder;
  canDrop:boolean;
  actionFilterValue?:string;
}

interface DropState {
  index:number;
  edge:'top' | 'bottom';
}

interface CardListItemProps {
  workPackage:WorkPackage;
  queryId:string;
  index:number;
  order:string[];
  positions:QueryOrder;
  canDrop:boolean;
  actionFilterValue?:string;
  dropState:DropState | null;
  onDropStateChange:(this:void, state:DropState | null) => void;
}

function CardListItem({
  workPackage,
  queryId,
  index,
  order,
  positions,
  canDrop,
  actionFilterValue,
  dropState,
  onDropStateChange,
}:CardListItemProps) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el || !canDrop) {
      return;
    }

    return dropTargetForElements({
      element: el,
      getData: ({ input, element }) =>
        attachClosestEdge(
          { type: 'card-drop-target', queryId, actionFilterValue, index, order, positions },
          { input, element, allowedEdges: ['top', 'bottom'] },
        ),
      canDrop: ({ source }) => source.data.type === 'card',
      onDrag: ({ self }) => {
        const edge = extractClosestEdge(self.data);
        onDropStateChange(edge === 'bottom' ? { index, edge: 'bottom' } : { index, edge: 'top' });
      },
      onDragLeave: () => onDropStateChange(null),
      onDrop: () => onDropStateChange(null),
    });
  }, [queryId, actionFilterValue, index, order, positions, canDrop, onDropStateChange]);

  return (
    <div ref={ref} style={{ position: 'relative' }}>
      {dropState?.index === index && dropState.edge === 'top' && (
        <DropIndicator edge="top" />
      )}
      <BoardCard
        workPackage={workPackage}
        queryId={queryId}
        index={index}
        order={order}
        positions={positions}
        isDragDisabled={!canDrop}
      />
      {dropState?.index === index && dropState.edge === 'bottom' && (
        <DropIndicator edge="bottom" />
      )}
    </div>
  );
}

export function CardList({
  workPackages,
  queryId,
  order,
  positions,
  canDrop,
  actionFilterValue,
}:CardListProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [dropState, setDropState] = useState<DropState | null>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el || !canDrop || workPackages.length > 0) return;

    return dropTargetForElements({
      element: el,
      getData: () => ({ type: 'card-list', queryId, actionFilterValue, index: 0, order, positions }),
      canDrop: ({ source }) => source.data.type === 'card',
      onDrag: () => setDropState({ index: 0, edge: 'top' }),
      onDragLeave: () => setDropState(null),
      onDrop: () => setDropState(null),
    });
  }, [queryId, order, positions, workPackages.length, canDrop, actionFilterValue]);

  return (
    <div
      ref={ref}
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: '8px',
        minHeight: '100px',
        padding: '8px',
        flexGrow: 1,
        overflowY: 'auto',
      }}
    >
      {workPackages.length === 0 && dropState?.index === 0 && (
        <DropIndicator edge="top" />
      )}

      {workPackages.map((wp, index) => (
        <CardListItem
          key={wp.id}
          workPackage={wp}
          queryId={queryId}
          index={index}
          order={order}
          positions={positions}
          canDrop={canDrop}
          actionFilterValue={actionFilterValue}
          dropState={dropState}
          onDropStateChange={setDropState}
        />
      ))}

      {workPackages.length === 0 && (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'var(--fgColor-muted, var(--color-fg-muted))',
            fontSize: '14px',
            padding: '16px 0',
          }}
        >
          No work packages
        </div>
      )}
    </div>
  );
}
