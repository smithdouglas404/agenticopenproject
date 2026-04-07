import React from 'react';
import { Text, CounterLabel } from '@primer/react';
import type { Status } from '../api/types';

interface ColumnHeaderProps {
  title:string;
  cardCount:number;
  status?:Status;
}

export function ColumnHeader({ title, cardCount, status }:ColumnHeaderProps) {
  return (
    <div
      className="op-board-list--header"
      data-test-selector="op-board-list--header"
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
        padding: '8px 12px',
        borderBottom: '1px solid var(--borderColor-default, var(--color-border-default))',
        flexShrink: 0,
      }}
    >
      {status?.color && (
        <span
          style={{
            width: '12px',
            height: '12px',
            borderRadius: '50%',
            backgroundColor: status.color,
            flexShrink: 0,
            display: 'inline-block',
          }}
        />
      )}
      <Text weight="semibold" size="medium" style={{ flexGrow: 1 }}>
        {title}
      </Text>
      <CounterLabel>{cardCount}</CounterLabel>
    </div>
  );
}
