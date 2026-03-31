import React, { useState } from 'react';
import { Box, Heading, IconButton } from '@primer/react';
import { FilterIcon } from '@primer/octicons-react';
import { BoardFilterBar } from './BoardFilterBar';
import type { ApiV3Filter } from '../api/types';

interface BoardToolbarProps {
  boardName: string;
  filters: ApiV3Filter[];
  onFiltersChange: (filters: ApiV3Filter[]) => void;
}

export function BoardToolbar({ boardName, filters, onFiltersChange }: BoardToolbarProps) {
  const [showFilters, setShowFilters] = useState(false);

  return (
    <Box sx={{ flexShrink: 0 }}>
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
        }}
      >
        <Heading as="h2" sx={{ fontSize: 2, flexGrow: 1 }}>
          {boardName}
        </Heading>

        <IconButton
          icon={FilterIcon}
          aria-label="Toggle filters"
          variant={showFilters ? 'default' : 'invisible'}
          onClick={() => setShowFilters(!showFilters)}
        />
      </Box>

      {showFilters && (
        <BoardFilterBar filters={filters} onFiltersChange={onFiltersChange} />
      )}
    </Box>
  );
}
