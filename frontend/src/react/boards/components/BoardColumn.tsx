import React, { useMemo } from 'react';
import { Spinner } from '@primer/react';
import { useColumnWorkPackages } from '../hooks/useColumnWorkPackages';
import { useStatuses } from '../hooks/useStatuses';
import { useBoardContext } from '../context/BoardContext';
import { ColumnHeader } from './ColumnHeader';
import { CardList } from './CardList';
import { AddCardAction } from './AddCardAction';
import type { GridWidget, ApiV3Filter } from '../api/types';
import {
  resolveActionFilterValue,
  resolveActionWidgetFilterValue,
} from '../support/action-filter-value';

interface BoardColumnProps {
  widget:GridWidget;
  filters:ApiV3Filter[];
}

export function BoardColumn({ widget, filters }:BoardColumnProps) {
  const { isActionBoard, actionAttribute } = useBoardContext();
  const queryId = String(widget.options.queryId ?? '');

  const { data: query, isLoading } = useColumnWorkPackages(
    queryId,
    filters,
    widget.options.filters,
  );

  const { data: statuses } = useStatuses();

  const actionFilterValue = useMemo(() => {
    if (!isActionBoard) {
      return undefined;
    }

    return resolveActionFilterValue(query?.filters, actionAttribute)
      ?? resolveActionWidgetFilterValue(widget.options.filters, actionAttribute);
  }, [isActionBoard, actionAttribute, query, widget.options.filters]);

  const columnStatus = useMemo(() => {
    if (!isActionBoard || actionAttribute !== 'status' || !statuses || !actionFilterValue) {
      return undefined;
    }
    return statuses.find((s) => String(s.id) === actionFilterValue);
  }, [isActionBoard, actionAttribute, statuses, actionFilterValue]);

  const workPackages = query?._embedded?.results?._embedded?.elements ?? [];
  const order = workPackages.map((wp) => String(wp.id));
  const positions = query?.ordered_work_packages ?? {};
  const columnTitle = query?.name ?? 'Loading...';
  const canDrop = !!query?._links?.updateOrderedWorkPackages
    && (!isActionBoard || !!actionFilterValue);

  return (
    <div
      className="op-board-list loading-indicator--location"
      data-test-selector="op-board-list"
      data-query-name={columnTitle}
      style={{
        display: 'flex',
        flexDirection: 'column',
        width: '300px',
        minWidth: '300px',
        backgroundColor: 'var(--bgColor-inset, var(--color-canvas-inset))',
        border: '1px solid var(--borderColor-default, var(--color-border-default))',
        borderRadius: '6px',
        overflow: 'hidden',
        flexShrink: 0,
      }}
    >
      <ColumnHeader
        title={columnTitle}
        cardCount={workPackages.length}
        status={columnStatus}
      />

      {isLoading ? (
        <div style={{ display: 'flex', justifyContent: 'center', padding: '16px 0' }}>
          <Spinner size="medium" />
        </div>
      ) : (
        <CardList
          workPackages={workPackages}
          queryId={queryId}
          order={order}
          positions={positions}
          canDrop={canDrop}
          actionFilterValue={actionFilterValue}
        />
      )}

      <AddCardAction queryId={queryId} />
    </div>
  );
}
