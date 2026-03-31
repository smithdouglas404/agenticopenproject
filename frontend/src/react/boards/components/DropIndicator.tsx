import React from 'react';

interface DropIndicatorProps {
  edge: 'top' | 'bottom';
}

export function DropIndicator({ edge }: DropIndicatorProps) {
  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        height: '2px',
        backgroundColor: 'var(--bgColor-accent-emphasis, var(--color-accent-emphasis))',
        borderRadius: '3px',
        ...(edge === 'top' ? { top: '-1px' } : { bottom: '-1px' }),
      }}
    />
  );
}
