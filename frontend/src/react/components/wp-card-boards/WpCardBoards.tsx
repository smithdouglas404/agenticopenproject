import React from 'react';
import { Avatar, Link } from '@primer/react';
import { Highlighting } from 'core-app/features/work-packages/components/wp-fast-table/builders/highlighting/highlighting.functions';
import type { WpCardData } from './types';
import './wp-card-boards.css';

export interface WpCardBoardsProps {
  workPackage:WpCardData;
  onCardClick?:(event:React.MouseEvent) => void;
  onCardDoubleClick?:(event:React.MouseEvent) => void;
  onCardContextMenu?:(event:React.MouseEvent) => void;
  onMenuClick?:(event:React.MouseEvent) => void;
  onIdClick?:(event:React.MouseEvent) => void;
}

function GrabberIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path d="M10 13a1 1 0 1 1 0-2 1 1 0 0 1 0 2Zm0-4a1 1 0 1 1 0-2 1 1 0 0 1 0 2Zm-4 4a1 1 0 1 1 0-2 1 1 0 0 1 0 2Zm5-9a1 1 0 1 1-2 0 1 1 0 0 1 2 0ZM7 8a1 1 0 1 1-2 0 1 1 0 0 1 2 0ZM6 5a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z" />
    </svg>
  );
}

function KebabHorizontalIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path d="M8 9a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM1.5 9a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Zm13 0a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z" />
    </svg>
  );
}

function PriorityDot({ priorityId }:{ priorityId?:string }) {
  const hlClass = priorityId
    ? Highlighting.colorClass(false, priorityId)
    : undefined;

  return (
    <span
      className={`op-wp-card-boards--priority-dot ${hlClass ?? ''}`}
      aria-hidden="true"
    />
  );
}

export function WpCardBoards({
  workPackage,
  onCardClick,
  onCardDoubleClick,
  onCardContextMenu,
  onMenuClick,
  onIdClick,
}:WpCardBoardsProps) {
  const typeHighlightClass = Highlighting.inlineClass('type', workPackage.typeId);

  const rootClasses = [
    'op-wp-card-boards',
    workPackage.selected && 'op-wp-card-boards--selected',
    workPackage.isClosed && 'op-wp-card-boards--closed',
  ].filter(Boolean).join(' ');

  return (
    <div
      className={rootClasses}
      data-test-selector="op-wp-card-boards"
      data-work-package-id={workPackage.id}
      role="button"
      tabIndex={0}
      title={workPackage.subject}
      onClick={onCardClick}
      onDoubleClick={onCardDoubleClick}
      onContextMenu={onCardContextMenu}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          onCardClick?.(e as unknown as React.MouseEvent);
        }
      }}
    >
      <div className="op-wp-card-boards--box">
        {workPackage.draggable && (
          <div className="op-wp-card-boards--grabber">
            <GrabberIcon />
          </div>
        )}

        <div className="op-wp-card-boards--body">
          <div className="op-wp-card-boards--header">
            <div className="op-wp-card-boards--labels">
              <span className={typeHighlightClass}>
                {workPackage.typeName}
              </span>
              <Link
                className="op-wp-card-boards--id"
                href="#"
                muted
                onClick={(e:React.MouseEvent) => {
                  e.stopPropagation();
                  onIdClick?.(e);
                }}
              >
                {workPackage.projectIdentifier}-{workPackage.id}
              </Link>
            </div>
            <button
              type="button"
              className="op-wp-card-boards--menu-button"
              aria-label="More actions"
              onClick={(e) => {
                e.stopPropagation();
                onMenuClick?.(e);
              }}
            >
              <KebabHorizontalIcon />
            </button>
          </div>

          <Link
            className="op-wp-card-boards--subject"
            href="#"
          >
            {workPackage.subject}
          </Link>

          <div className="op-wp-card-boards--footer">
            <div className="op-wp-card-boards--assignee">
              {workPackage.assigneeAvatarUrl && (
                <Avatar
                  src={workPackage.assigneeAvatarUrl}
                  size={16}
                  alt={workPackage.assigneeName ?? ''}
                />
              )}
              {workPackage.assigneeName && (
                <span className="op-wp-card-boards--assignee-name">
                  {workPackage.assigneeName}
                </span>
              )}
            </div>

            {workPackage.storyPoints != null && (
              <span className="op-wp-card-boards--story-points">
                {workPackage.storyPoints}
              </span>
            )}

            {workPackage.priorityName && (
              <div className="op-wp-card-boards--priority">
                <PriorityDot priorityId={workPackage.priorityId} />
                <span className="op-wp-card-boards--priority-name">
                  {workPackage.priorityName}
                </span>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
