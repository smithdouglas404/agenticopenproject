import React from 'react';
import { Box, Text, CounterLabel } from '@primer/react';
import type { Status } from '../api/types';

interface ColumnHeaderProps {
  title: string;
  cardCount: number;
  status?: Status;
}

export function ColumnHeader({ title, cardCount, status }: ColumnHeaderProps) {
  return (
    <Box
      sx={{
        display: 'flex',
        alignItems: 'center',
        gap: 2,
        px: 3,
        py: 2,
        borderBottomWidth: 1,
        borderBottomStyle: 'solid',
        borderBottomColor: 'border.default',
        flexShrink: 0,
      }}
    >
      {status?.color && (
        <Box
          sx={{
            width: 12,
            height: 12,
            borderRadius: '50%',
            bg: status.color,
            flexShrink: 0,
          }}
        />
      )}
      <Text sx={{ fontWeight: 'semibold', fontSize: 1, flexGrow: 1 }}>
        {title}
      </Text>
      <CounterLabel>{cardCount}</CounterLabel>
    </Box>
  );
}
