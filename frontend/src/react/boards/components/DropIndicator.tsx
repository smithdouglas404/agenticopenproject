import React from 'react';
import { Box } from '@primer/react';

interface DropIndicatorProps {
  edge: 'top' | 'bottom';
}

export function DropIndicator({ edge }: DropIndicatorProps) {
  return (
    <Box
      sx={{
        position: 'absolute',
        left: 0,
        right: 0,
        height: '2px',
        bg: 'accent.emphasis',
        borderRadius: 1,
        ...(edge === 'top' ? { top: '-1px' } : { bottom: '-1px' }),
      }}
    />
  );
}
