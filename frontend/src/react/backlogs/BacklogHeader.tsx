import { CheckIcon, UndoIcon, PencilIcon } from '@primer/octicons-react';
import { Stack, IconButton, Text } from '@primer/react';
import { useState, useEffect } from 'react';
import { BacklogMenu } from './BacklogMenu';
import { InlineDateRangeField } from './InlineDateRangeField';
import InlineTextField from './InlineTextField';
import { BacklogProps } from './BacklogTable';


export function BacklogHeader({backlog}:BacklogProps) {
  const [isEditing, setIsEditing] = useState(false);

  const [formValues, setFormValues] = useState({
      startDate: backlog.sprint.start_date!,
      endDate: backlog.sprint.effective_date!,
      name: backlog.sprint.name
  });

  const resetForm = () => {
    setFormValues({
      startDate: backlog.sprint.start_date!,
      endDate: backlog.sprint.effective_date!,
      name: backlog.sprint.name
    });
  };

  useEffect(() => { resetForm(); }, [backlog]);

  const handleInputChange = (field:string, value:string) => {
    setFormValues((current) => ({
      ...current,
      [field]: value,
    }));
  };

  const handleSave = () => {
    // mutate({
    //   type_id: formValues.type_id,
    //   subject: formValues.subject,
    //   status_id: formValues.status_id,
    //   story_points: formValues.story_points
    // });
    setIsEditing(false);
  };

  const handleCancel = () => {
    resetForm();
    setIsEditing(false);
  };


  if (isEditing) {
    return (
      <Stack direction='horizontal' align='center' gap="condensed"> 
        <Stack.Item grow>
          <InlineTextField
            value={formValues.name}
            onChange={(event) => handleInputChange('name', event.target.value)}
          ></InlineTextField>
        </Stack.Item>
        <Stack.Item grow>
            <InlineDateRangeField value={[formValues.startDate, formValues.endDate]}
              onChange={([newstartDate, newEndDate]) => { handleInputChange('startDate', newstartDate); handleInputChange('endDate', newEndDate); }}></InlineDateRangeField>
        </Stack.Item>
        <IconButton icon={CheckIcon}  onClick={() => {}} variant="primary" aria-label="Save" />
        <IconButton icon={UndoIcon} aria-label="Cancel" onClick={handleCancel} />
      </Stack>
    );
  }

  return (
    <Stack direction='horizontal' align='center' gap="condensed">
      <Stack.Item grow>
        <Text weight='semibold'>{backlog.sprint.name}</Text>
      </Stack.Item>
      <IconButton variant="invisible" icon={PencilIcon} aria-label="Edit" onClick={() => setIsEditing(true)} />
      <BacklogMenu sprintId={backlog.sprint.id} onNewStory={() => {}}></BacklogMenu>
    </Stack>
  );
}
