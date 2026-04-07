import React, { useState } from 'react';
import { Heading, IconButton } from '@primer/react';
import { FilterIcon } from '@primer/octicons-react';
import { BoardFilterBar } from './BoardFilterBar';
import type { ApiV3Filter } from '../api/types';

interface BoardToolbarProps {
  boardName:string;
  filters:ApiV3Filter[];
  onFiltersChange:(filters:ApiV3Filter[]) => void;
}

export function BoardToolbar({ boardName, filters, onFiltersChange }:BoardToolbarProps) {
  const [showFilters, setShowFilters] = useState(false);

  return (
    <div style={{ flexShrink: 0 }}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: '8px',
          padding: '8px 12px',
          borderBottom: '1px solid var(--borderColor-default, var(--color-border-default))',
        }}
      >
        <Heading as="h2" className="f2" style={{ flexGrow: 1 }}>
          {boardName}
        </Heading>

        <IconButton
          icon={FilterIcon}
          aria-label="Toggle filters"
          variant={showFilters ? 'default' : 'invisible'}
          onClick={() => setShowFilters(!showFilters)}
        />
      </div>

      {showFilters && (
        <BoardFilterBar filters={filters} onFiltersChange={onFiltersChange} />
      )}
    </div>
  );
}
