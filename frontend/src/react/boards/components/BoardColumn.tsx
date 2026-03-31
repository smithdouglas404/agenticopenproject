import React, { useMemo } from 'react';
import { Box, Spinner } from '@primer/react';
import { useColumnWorkPackages } from '../hooks/useColumnWorkPackages';
import { useStatuses } from '../hooks/useStatuses';
import { useBoardContext } from '../context/BoardContext';
import { ColumnHeader } from './ColumnHeader';
import { CardList } from './CardList';
import { AddCardAction } from './AddCardAction';
import type { GridWidget, ApiV3Filter } from '../api/types';

interface BoardColumnProps {
  widget: GridWidget;
  filters: ApiV3Filter[];
}

export function BoardColumn({ widget, filters }: BoardColumnProps) {
  const { isActionBoard, actionAttribute } = useBoardContext();
  const queryId = widget.options.queryId ?? '';

  const { data: query, isLoading } = useColumnWorkPackages(
    queryId,
    filters,
    widget.options.filters,
  );

  const { data: statuses } = useStatuses();

  const columnStatus = useMemo(() => {
    if (!isActionBoard || actionAttribute !== 'status' || !statuses || !query) {
      return undefined;
    }

    const statusFilter = query.filters?.find(
      (f) => 'status' in f || 'statusId' in f || 'status_id' in f,
    );
    if (!statusFilter) return undefined;

    const filterValue = (statusFilter as Record<string, any>).status
      ?? (statusFilter as Record<string, any>).statusId
      ?? (statusFilter as Record<string, any>).status_id;
    const statusId = filterValue?.values?.[0];
    if (!statusId) return undefined;

    return statuses.find((s) => String(s.id) === String(statusId));
  }, [isActionBoard, actionAttribute, statuses, query]);

  const actionFilterValue = useMemo(() => {
    if (!isActionBoard || !query?.filters) return undefined;

    for (const filter of query.filters) {
      const key = Object.keys(filter).find(
        (k) => k === actionAttribute || k === `${actionAttribute}Id` || k === `${actionAttribute}_id`,
      );
      if (key) return filter[key].values?.[0];
    }
    return undefined;
  }, [isActionBoard, actionAttribute, query]);

  const workPackages = query?.results?._embedded?.elements ?? [];
  const columnTitle = query?.name ?? 'Loading...';
  const canDrop = !!query?._links?.updateOrderedWorkPackages;

  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        width: '300px',
        minWidth: '300px',
        bg: 'canvas.inset',
        borderWidth: 1,
        borderStyle: 'solid',
        borderColor: 'border.default',
        borderRadius: 2,
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
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
          <Spinner size="medium" />
        </Box>
      ) : (
        <CardList
          workPackages={workPackages}
          queryId={queryId}
          canDrop={canDrop}
          actionFilterValue={actionFilterValue}
        />
      )}

      <AddCardAction queryId={queryId} />
    </Box>
  );
}
