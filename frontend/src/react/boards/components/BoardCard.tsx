import React, { useRef, useEffect, useState } from 'react';
import { Text, Truncate } from '@primer/react';
import { draggable } from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import type { QueryOrder } from '../dnd/query-order';
import type { WorkPackage } from '../api/types';

interface BoardCardProps {
  workPackage:WorkPackage;
  queryId:string;
  index:number;
  order:string[];
  positions:QueryOrder;
  isDragDisabled?:boolean;
}

export function BoardCard({
  workPackage,
  queryId,
  index,
  order,
  positions,
  isDragDisabled,
}:BoardCardProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [isDragging, setIsDragging] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el || isDragDisabled) return;

    return draggable({
      element: el,
      getInitialData: () => ({
        type: 'card',
        workPackageId: workPackage.id,
        lockVersion: workPackage.lockVersion,
        sourceQueryId: queryId,
        index,
        order,
        positions,
      }),
      onDragStart: () => setIsDragging(true),
      onDrop: () => setIsDragging(false),
    });
  }, [workPackage.id, workPackage.lockVersion, queryId, index, order, positions, isDragDisabled]);

  const wpPath = `/work_packages/${workPackage.id}`;
  const typeName = workPackage._links.type?.title ?? '';
  const statusName = workPackage._links.status?.title ?? '';
  const assigneeName = workPackage._links.assignee?.title;

  return (
    <div
      ref={ref}
      className="op-board-card"
      data-test-selector="op-wp-single-card"
      data-qa-draggable={isDragDisabled ? undefined : 'true'}
      style={{
        padding: '12px',
        backgroundColor: 'var(--bgColor-default, var(--color-canvas-default))',
        border: '1px solid var(--borderColor-default, var(--color-border-default))',
        borderRadius: '6px',
        cursor: isDragDisabled ? 'default' : 'grab',
        opacity: isDragging ? 0.5 : 1,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: '4px', marginBottom: '4px' }}>
        <Text size="small" className="color-fg-muted" data-test-selector="op-wp-single-card--content-type">{typeName}</Text>
        <Text size="small" className="color-fg-muted">#{workPackage.id}</Text>
      </div>

      <a
        href={wpPath}
        data-test-selector="op-wp-single-card--content-subject"
        style={{
          color: 'var(--fgColor-default, var(--color-fg-default))',
          textDecoration: 'none',
          fontWeight: 600,
          fontSize: '14px',
          display: 'block',
          marginBottom: '8px',
        }}
      >
        <Truncate title={workPackage.subject} maxWidth="100%">
          {workPackage.subject}
        </Truncate>
      </a>

      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Text size="small" className="color-fg-muted" data-test-selector="op-wp-single-card--content-status">{statusName}</Text>
        {assigneeName && (
          <Text size="small" className="color-fg-muted" data-test-selector="op-wp-single-card--content-assignee">{assigneeName}</Text>
        )}
      </div>
    </div>
  );
}
