import React, { useRef, useState, useCallback, useMemo } from 'react';
import { ActionList, SelectPanel } from '@primer/react';
import type { SelectPanelItemInput } from '@primer/react';
import { Highlighting } from 'core-app/features/work-packages/components/wp-fast-table/builders/highlighting/highlighting.functions';
import type { DialogBridgeProps } from '../../bridge/types';
import type { StatusOption } from './types';

export interface StatusMappingDialogProps extends DialogBridgeProps<string[]> {
  currentFilterValues:string[];
  availableStatuses:StatusOption[];
  title:string;
  subtitle:string;
  placeholder:string;
  noSelectionNotice:string;
}

export function StatusMappingDialog({
  currentFilterValues,
  availableStatuses,
  title,
  subtitle,
  placeholder,
  noSelectionNotice,
  onSubmit,
  onCancel,
}:StatusMappingDialogProps) {
  const anchorRef = useRef<HTMLSpanElement>(null);
  const statusById = useMemo(
    () => new Map(availableStatuses.map((status) => [String(status.id), status])),
    [availableStatuses],
  );

  const items:SelectPanelItemInput[] = useMemo(
    () =>
      availableStatuses.map((s) => ({
        id: s.id,
        text: s.name,
      })),
    [availableStatuses],
  );

  const [selected, setSelected] = useState<SelectPanelItemInput[]>(() =>
    items.filter((item) => currentFilterValues.includes(String(item.id))),
  );

  const [filterValue, setFilterValue] = useState('');
  const normalizedFilterValue = filterValue.trim().toLocaleLowerCase();

  const filteredItems = useMemo(
    () => (normalizedFilterValue.length > 0
      ? items.filter((item) => String(item.text ?? '').toLocaleLowerCase().includes(normalizedFilterValue))
      : items),
    [items, normalizedFilterValue],
  );

  const noneSelected = selected.length === 0;

  const handleSelectedChange = useCallback((newSelected:SelectPanelItemInput[]) => {
    setSelected(newSelected);
  }, []);

  const handleFilterChange = useCallback((value:string) => {
    setFilterValue(value);
  }, []);

  const renderStatusItem = useCallback((item:SelectPanelItemInput) => {
    const { id, text, onAction, children } = item;
    const status = id !== undefined ? statusById.get(String(id)) : undefined;
    const labelClass = status ? Highlighting.inlineClass('status', status.id) : undefined;
    const className = 'className' in item ? item.className : undefined;
    const selected = 'selected' in item ? item.selected : undefined;
    const disabled = 'disabled' in item ? item.disabled : undefined;
    const variant = 'variant' in item ? item.variant : undefined;

    return (
      <ActionList.Item
        role="option"
        id={id !== undefined ? String(id) : undefined}
        onSelect={(event) => onAction?.(item, event as React.MouseEvent<HTMLDivElement> | React.KeyboardEvent<HTMLDivElement>)}
        data-id={id}
        className={className}
        selected={selected}
        disabled={disabled}
        variant={variant}
      >
        {children}
        <span className={labelClass}>
          {text}
        </span>
      </ActionList.Item>
    );
  }, [statusById]);

  const handleOpenChange = useCallback(
    (open:boolean, gesture:string) => {
      if (!open) {
        if (gesture === 'escape' || gesture === 'cancel') {
          onCancel();
        } else {
          const ids = selected.map((item) => String(item.id));
          if (ids.length > 0) {
            onSubmit(ids);
          } else {
            onCancel();
          }
        }
      }
    },
    [selected, onSubmit, onCancel],
  );

  return (
    <>
      <span ref={anchorRef} style={{ position: 'fixed', top: 0, left: 0, width: 0, height: 0, pointerEvents: 'none' }} />
      <SelectPanel
        title={title}
        subtitle={subtitle}
        placeholder={placeholder}
        variant="modal"
        open={true}
        onOpenChange={handleOpenChange}
        onCancel={onCancel}
        renderAnchor={null}
        anchorRef={anchorRef}
        items={filteredItems}
        selected={selected}
        onSelectedChange={handleSelectedChange}
        renderItem={renderStatusItem}
        filterValue={filterValue}
        onFilterChange={handleFilterChange}
        loading={false}
        height="medium"
        overlayProps={{ width: 'medium' }}
        {...(noneSelected
          ? { notice: { text: noSelectionNotice, variant: 'warning' as const } }
          : {})}
      />
    </>
  );
}
