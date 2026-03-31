import React from 'react';
import { Box, Text } from '@primer/react';
import type { ApiV3Filter } from '../api/types';

interface BoardFilterBarProps {
  filters: ApiV3Filter[];
  onFiltersChange: (filters: ApiV3Filter[]) => void;
}

export function BoardFilterBar({ filters, onFiltersChange }: BoardFilterBarProps) {
  return (
    <Box
      sx={{
        px: 3,
        py: 2,
        bg: 'canvas.inset',
        borderBottomWidth: 1,
        borderBottomStyle: 'solid',
        borderBottomColor: 'border.default',
      }}
    >
      <Text sx={{ fontSize: 1, color: 'fg.muted' }}>
        Filters — coming soon
      </Text>
    </Box>
  );
}
