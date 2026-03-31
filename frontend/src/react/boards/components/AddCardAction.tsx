import React from 'react';
import { Button } from '@primer/react';
import { PlusIcon } from '@primer/octicons-react';

interface AddCardActionProps {
  queryId: string;
}

export function AddCardAction({ queryId }: AddCardActionProps) {
  const handleClick = () => {
    window.location.href = '/work_packages/new';
  };

  return (
    <div style={{ padding: '8px', borderTop: '1px solid var(--borderColor-default, var(--color-border-default))' }}>
      <Button
        variant="invisible"
        size="small"
        leadingVisual={PlusIcon}
        onClick={handleClick}
        style={{ width: '100%', justifyContent: 'flex-start' }}
      >
        Add card
      </Button>
    </div>
  );
}
