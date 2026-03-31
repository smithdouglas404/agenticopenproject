import React from 'react';
import { Box, Button } from '@primer/react';
import { PlusIcon } from '@primer/octicons-react';
import { useBoardContext } from '../context/BoardContext';

export function AddColumnAction() {
  const { permissions, isActionBoard } = useBoardContext();

  if (!permissions.canManage) return null;

  const handleClick = () => {
    // v1: Placeholder — full add-list modal deferred
    console.log('Add column clicked — not yet implemented');
  };

  return (
    <Box
      sx={{
        display: 'flex',
        alignItems: 'flex-start',
        pt: 2,
        flexShrink: 0,
      }}
    >
      <Button
        variant="invisible"
        leadingVisual={PlusIcon}
        onClick={handleClick}
      >
        Add list
      </Button>
    </Box>
  );
}
