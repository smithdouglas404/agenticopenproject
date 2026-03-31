import React, { useRef, useEffect, useState } from 'react';
import { Box, Text, Truncate } from '@primer/react';
import { draggable } from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import type { WorkPackage } from '../api/types';

interface BoardCardProps {
  workPackage: WorkPackage;
  queryId: string;
  index: number;
  isDragDisabled?: boolean;
}

export function BoardCard({
  workPackage,
  queryId,
  index,
  isDragDisabled,
}: BoardCardProps) {
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
      }),
      onDragStart: () => setIsDragging(true),
      onDrop: () => setIsDragging(false),
    });
  }, [workPackage.id, workPackage.lockVersion, queryId, index, isDragDisabled]);

  const wpPath = `/work_packages/${workPackage.id}`;
  const typeName = workPackage._links.type?.title ?? '';
  const statusName = workPackage._links.status?.title ?? '';
  const assigneeName = workPackage._links.assignee?.title;

  return (
    <Box
      ref={ref}
      as="div"
      className="op-board-card"
      sx={{
        p: 3,
        bg: 'canvas.default',
        borderWidth: 1,
        borderStyle: 'solid',
        borderColor: 'border.default',
        borderRadius: 2,
        cursor: isDragDisabled ? 'default' : 'grab',
        opacity: isDragging ? 0.5 : 1,
        '&:hover': { borderColor: 'accent.emphasis' },
      }}
    >
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
        <Text sx={{ fontSize: 0, color: 'fg.muted' }}>{typeName}</Text>
        <Text sx={{ fontSize: 0, color: 'fg.muted' }}>#{workPackage.id}</Text>
      </Box>

      <Box
        as="a"
        href={wpPath}
        sx={{
          color: 'fg.default',
          textDecoration: 'none',
          fontWeight: 'semibold',
          fontSize: 1,
          display: 'block',
          mb: 2,
          '&:hover': { textDecoration: 'underline' },
        }}
      >
        <Truncate title={workPackage.subject} maxWidth="100%">
          {workPackage.subject}
        </Truncate>
      </Box>

      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Text sx={{ fontSize: 0, color: 'fg.muted' }}>{statusName}</Text>
        {assigneeName && (
          <Text sx={{ fontSize: 0, color: 'fg.muted' }}>{assigneeName}</Text>
        )}
      </Box>
    </Box>
  );
}
