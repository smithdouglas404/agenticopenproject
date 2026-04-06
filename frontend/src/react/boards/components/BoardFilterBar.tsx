import React from 'react';
import { Text } from '@primer/react';
import type { ApiV3Filter } from '../api/types';

interface BoardFilterBarProps {
  filters:ApiV3Filter[];
  onFiltersChange:(filters:ApiV3Filter[]) => void;
}

export function BoardFilterBar({ filters, onFiltersChange }:BoardFilterBarProps) {
  void filters;
  void onFiltersChange;

  return (
    <div
      style={{
        padding: '8px 12px',
        backgroundColor: 'var(--bgColor-inset, var(--color-canvas-inset))',
        borderBottom: '1px solid var(--borderColor-default, var(--color-border-default))',
      }}
    >
      <Text size="small" className="color-fg-muted">
        Filters — coming soon
      </Text>
    </div>
  );
}
