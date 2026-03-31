import React from 'react';
import { Box, Button } from '@primer/react';
import { PlusIcon } from '@primer/octicons-react';

interface AddCardActionProps {
  queryId: string;
}

export function AddCardAction({ queryId }: AddCardActionProps) {
  const handleClick = () => {
    window.location.href = '/work_packages/new';
  };

  return (
    <Box sx={{ p: 2, borderTopWidth: 1, borderTopStyle: 'solid', borderTopColor: 'border.default' }}>
      <Button
        variant="invisible"
        size="small"
        leadingVisual={PlusIcon}
        onClick={handleClick}
        sx={{ width: '100%', justifyContent: 'flex-start' }}
      >
        Add card
      </Button>
    </Box>
  );
}
