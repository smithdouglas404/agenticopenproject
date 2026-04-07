import React, { useRef, useEffect, useState } from 'react';
import { GrabberIcon } from '@primer/octicons-react';
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

function priorityDotColor(priorityName:string):string {
  const normalized = priorityName.toLowerCase();

  if (normalized.includes('immediate') || normalized.includes('critical') || normalized.includes('high')) {
    return 'var(--control-danger-fgColor-rest, #d1242f)';
  }

  if (normalized.includes('low')) {
    return 'var(--fgColor-muted, var(--color-fg-muted))';
  }

  return 'var(--data-teal-color-emphasis, #179b9b)';
}

function assigneeInitials(name:string):string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? '')
    .join('');
}

function typeHighlightClass(typeHref:string | undefined):string | undefined {
  const match = typeHref?.match(/\/types\/(\d+)(?:[/?#].*)?$/);

  if (!match) {
    return undefined;
  }

  return `__hl_inline_type_${match[1]}`;
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
  const priorityName = workPackage._links.priority?.title ?? '';
  const typeLabel = typeName.toUpperCase();
  const typeClassName = typeHighlightClass(workPackage._links.type?.href);

  return (
    <div
      ref={ref}
      className="op-board-card"
      data-test-selector="op-wp-single-card"
      data-qa-draggable={isDragDisabled ? undefined : 'true'}
      style={{
        display: 'flex',
        gap: '4px',
        alignItems: 'stretch',
        padding: '8px 16px 6px 8px',
        backgroundColor: 'var(--bgColor-default, var(--color-canvas-default))',
        border: '1px solid rgba(208, 215, 222, 0.48)',
        borderRadius: '6px',
        cursor: isDragDisabled ? 'default' : 'grab',
        opacity: isDragging ? 0.5 : 1,
        boxShadow: '0 1px 0 rgba(0, 0, 0, 0.04), 0 1px 3px rgba(0, 0, 0, 0.04)',
      }}
    >
      <div
        data-test-selector="op-board-card--drag-handle"
        style={{
          display: 'flex',
          alignItems: 'flex-start',
          paddingTop: '4px',
          color: 'var(--fgColor-muted, var(--color-fg-muted))',
          flexShrink: 0,
        }}
      >
        <GrabberIcon size={16} />
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', flex: '1 1 auto', minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: '8px' }}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '2px', minWidth: 0, flex: '1 1 auto' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: 0 }}>
              <Text
                size="small"
                weight="semibold"
                className={typeClassName}
                data-test-selector="op-board-card--type"
                style={{
                  color: typeClassName ? undefined : 'var(--fgColor-attention, #bf8700)',
                  fontSize: '12px',
                  lineHeight: '20px',
                  letterSpacing: 0,
                }}
              >
                {typeLabel}
              </Text>
              <Text
                size="small"
                className="color-fg-muted"
                data-test-selector="op-board-card--reference"
                style={{
                  fontSize: '12px',
                  lineHeight: '20px',
                }}
              >
                #{workPackage.id}
              </Text>
            </div>

            <a
              href={wpPath}
              data-test-selector="op-wp-single-card--content-subject"
              style={{
                color: 'var(--fgColor-link, var(--color-accent-fg))',
                textDecoration: 'none',
                fontWeight: 600,
                fontSize: '14px',
                lineHeight: '20px',
                display: 'block',
              }}
            >
              <Truncate title={workPackage.subject} maxWidth="100%">
                {workPackage.subject}
              </Truncate>
            </a>
          </div>
        </div>

        <div
          data-test-selector="op-board-card--footer"
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: '12px',
            paddingTop: '4px',
            minWidth: 0,
          }}
        >
          {assigneeName && (
            <div style={{ display: 'flex', alignItems: 'center', gap: '6px', minWidth: 0, flex: '1 1 auto' }}>
              <div
                aria-hidden="true"
                style={{
                  width: '16px',
                  height: '16px',
                  borderRadius: '9999px',
                  border: '1px solid rgba(31, 35, 40, 0.15)',
                  backgroundColor: 'var(--bgColor-muted, var(--color-canvas-subtle))',
                  color: 'var(--fgColor-muted, var(--color-fg-muted))',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '9px',
                  fontWeight: 600,
                  flexShrink: 0,
                }}
              >
                {assigneeInitials(assigneeName)}
              </div>
              <Text
                size="small"
                className="color-fg-muted"
                data-test-selector="op-wp-single-card--content-assignee"
                style={{
                  fontSize: '12px',
                  lineHeight: '20px',
                  minWidth: 0,
                }}
              >
                <Truncate title={assigneeName} maxWidth="100%">
                  {assigneeName}
                </Truncate>
              </Text>
            </div>
          )}

          <Text
            size="small"
            className="color-fg-muted"
            data-test-selector="op-wp-single-card--content-status"
            style={{
              fontSize: '12px',
              lineHeight: '20px',
              flexShrink: 0,
            }}
          >
            {statusName}
          </Text>

          {priorityName && (
            <div
              data-test-selector="op-board-card--content-priority"
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                flexShrink: 0,
              }}
            >
              <span
                aria-hidden="true"
                style={{
                  width: '6px',
                  height: '6px',
                  borderRadius: '9999px',
                  backgroundColor: priorityDotColor(priorityName),
                }}
              />
              <Text
                size="small"
                className="color-fg-muted"
                style={{
                  fontSize: '12px',
                  lineHeight: '20px',
                }}
              >
                {priorityName}
              </Text>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
