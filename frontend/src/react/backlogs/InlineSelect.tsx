
import React from 'react';
import {Button, FormControl, SelectPanel, SelectPanelProps} from '@primer/react';
import {TriangleDownIcon} from '@primer/octicons-react';
import {type ActionListItemInput} from '@primer/react/deprecated';
import { useQuery } from '@tanstack/react-query';



export type InlineSelectItemInput<Id> = ActionListItemInput & { id:Id };
export interface InlineSelectProps<T> {
  items:InlineSelectItemInput<T>[];
  selectedId:T;
  onSelectedIdChange:((selected:T|undefined) => void)
}

export default function InlineSelect<T>({ items, selectedId, onSelectedIdChange }:InlineSelectProps<T>) {
  const selected = items.find((item) => item.id === selectedId) ?? items[0];
  const [open, setOpen] = React.useState(false);
  const [filter, setFilter] = React.useState('');
  const filteredItems = items.filter(
    item => item.text === selected?.text || item.text?.toLowerCase().startsWith(filter.toLowerCase()),
  );

  if (!items) return <div>Loading...</div>;

  return (
    <FormControl>
      <FormControl.Label visuallyHidden={true}>Type</FormControl.Label>
      <SelectPanel
        renderAnchor={({children, ...anchorProps}) => (
          <Button {...anchorProps} block trailingAction={TriangleDownIcon} aria-haspopup="dialog">
            {children}
          </Button>
        )}
        placeholder="Pick one choice"
        open={open}
        onOpenChange={setOpen}
        items={filteredItems}
        selected={selected}
        onSelectedChange={(item?:InlineSelectItemInput<T>) => { if (item?.id) onSelectedIdChange(item.id); }}
        onFilterChange={setFilter}
      />
    </FormControl>
  );
}
