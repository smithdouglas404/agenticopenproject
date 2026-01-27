import React, { useState } from 'react';
import { Avatar, Button, FormControl, SelectPanel } from '@primer/react';
import { TriangleDownIcon } from '@primer/octicons-react';
import { type ActionListItemInput } from '@primer/react/deprecated';
import { User, useAssignableUsers } from './queries';
import { Principal } from './Principal';

export type AssigneeItemInput = ActionListItemInput & { id:number|null };

export interface AssigneeSelectProps {
  projectId:string;
  selectedId:number|undefined;
  onSelectedIdChange:(id:number|undefined) => void;
}

export default function AssigneeSelect({ projectId, selectedId, onSelectedIdChange }:AssigneeSelectProps) {
  const { data, isLoading } = useAssignableUsers(projectId);
  const [open, setOpen] = useState(false);
  const [filter, setFilter] = useState('');

  const users = data?._embedded?.elements ?? [];

  const items:AssigneeItemInput[] = [
    { id: null as unknown as number, text: '(Unassigned)' },
    ...users.map((user:User) => ({
      id: user.id,
      text: user.name,
      leadingVisual: () => <Principal id={user.id} name={user.name} hideName={true} />
    }))
  ];

  const selected = items.find((item) => item.id === (selectedId ?? null)) ?? items[0];

  const filteredItems = items.filter(
    item => item.text === selected?.text || item.text?.toLowerCase().includes(filter.toLowerCase()),
  );

  if (isLoading) return <Button disabled block>Loading...</Button>;

  return (
    <FormControl>
      <FormControl.Label>Assignee</FormControl.Label>
      <SelectPanel
        renderAnchor={({ children, ...anchorProps }) => (
          <Button {...anchorProps} 
            leadingVisual={selected.leadingVisual} 
            trailingAction={TriangleDownIcon} 
            aria-haspopup="dialog">
            {children}
          </Button>
        )}
        placeholder="Select assignee"
        open={open}
        onOpenChange={setOpen}
        items={filteredItems}
        selected={selected}
        onSelectedChange={(item?:AssigneeItemInput) => {
          onSelectedIdChange(item?.id ?? undefined);
        }}
        onFilterChange={setFilter}
      />
    </FormControl>
  );
}
