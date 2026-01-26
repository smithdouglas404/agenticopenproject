import React, { useState, useEffect } from 'react';
import { Dialog, FormControl, TextInput } from '@primer/react';
import AssigneeSelect from './AssigneeSelect';
import { Task } from './queries';

export interface TaskDialogProps {
  isOpen:boolean;
  onClose:() => void;
  onSave:(data:TaskDialogFormData) => void;
  task?:Task;
  storyId:number;
  projectId:string;
}

export interface TaskDialogFormData {
  subject:string;
  assigned_to_id?:number;
  remaining_hours:number|null;
}

export default function TaskDialog({ isOpen, onClose, onSave, task, storyId: _storyId, projectId }:TaskDialogProps) {
  const isEditMode = !!task;
  const [subject, setSubject] = useState('');
  const [assignedToId, setAssignedToId] = useState<number|undefined>(undefined);
  const [remainingHours, setRemainingHours] = useState<string>('');

  useEffect(() => {
    if (task) {
      setSubject(task.subject);
      setAssignedToId(task.assigned_to?.id);
      setRemainingHours(task.remaining_hours?.toString() ?? '');
    } else {
      setSubject('');
      setAssignedToId(undefined);
      setRemainingHours('');
    }
  }, [task, isOpen]);

  const handleSave = () => {
    const hours = remainingHours === '' ? null : parseFloat(remainingHours);
    onSave({
      subject,
      assigned_to_id: assignedToId,
      remaining_hours: hours,
    });
  };

  const handleRemainingHoursChange = (e:React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    if (value === '' || /^\d*\.?\d*$/.test(value)) {
      setRemainingHours(value);
    }
  };

  if (!isOpen) return null;

  return (
    <Dialog
      title={isEditMode ? 'Edit task' : 'New task'}
      onClose={onClose}
      footerButtons={[
        { content: 'Cancel', onClick: onClose },
        { content: 'Save', buttonType: 'primary', onClick: handleSave, disabled: !subject.trim() },
      ]}
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
        <FormControl>
          <FormControl.Label>Subject</FormControl.Label>
          <TextInput
            value={subject}
            onChange={(e) => setSubject(e.target.value)}
            placeholder="Enter task subject"
            block
            autoFocus
          />
        </FormControl>

        <AssigneeSelect
          projectId={projectId}
          selectedId={assignedToId}
          onSelectedIdChange={setAssignedToId}
        />

        <FormControl>
          <FormControl.Label>Remaining work</FormControl.Label>
          <TextInput
            value={remainingHours}
            onChange={handleRemainingHoursChange}
            placeholder="e.g. 4"
            trailingVisual={'hours'}
          />
        </FormControl>
      </div>
    </Dialog>
  );
}
