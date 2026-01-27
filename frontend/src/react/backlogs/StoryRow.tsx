import { CheckIcon, PencilIcon, UndoIcon } from '@primer/octicons-react';
import { IconButton, Link, Label, Text, Stack, CounterLabel } from '@primer/react';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { useMemo, useState, useEffect, useRef } from 'react';
import { Story, StoryExpanded, useProjectQueries } from './queries';
import { useDrag, useDrop } from 'react-dnd';
import InlineTextField from './InlineTextField';
import StatusSelect from './StatusSelect';
import TypeSelect from './TypeSelect';
import { useSubmitForm } from './mutations';
import { StoryMenu } from './StoryMenu';
import { useProjectIdentifier } from '../hooks/useProjectIdentifier';

interface DragItem {
  id:string | number;   // usually number or string
  index:number;         // always a number
  type:string;          // this is required by react-dnd
}

interface DragCollected {
  isDragging:boolean;
}

interface StoryRowProps {
  story:StoryExpanded;
  sprintId:number|string;
  projectId:number|string;
  index:number;
  moveItem:(dragIndex:number, hoverIndex:number) => void;
  getCurrentPosition:(id:number | string) => number;
  updatePosition:(id:number | string, position:number) => void;
}

const ItemType = 'LIST_ITEM';

export function StoryRow({
  story, 
  sprintId, 
  projectId, 
  index, 
  moveItem, 
  getCurrentPosition, 
  updatePosition
}:StoryRowProps) {
  const projectIdentifier = useProjectIdentifier();

  const ref = useRef<HTMLDivElement>(null);
  
  //
  // DROP TARGET
  //
  const [, drop] = useDrop<DragItem>({
    accept: ItemType,
    hover(item, monitor) {
      if (!ref.current) return;

      const dragIndex = item.index;
      const hoverIndex = index;

      if (dragIndex === hoverIndex) return;

      const hoverRect = ref.current.getBoundingClientRect();
      const hoverMiddleY = (hoverRect.bottom - hoverRect.top) / 2;

      const clientOffset = monitor.getClientOffset();
      if (!clientOffset) return;

      const hoverClientY = clientOffset.y - hoverRect.top;

      // Only reorder when cursor crosses halfway point
      if (dragIndex < hoverIndex && hoverClientY < hoverMiddleY) return;
      if (dragIndex > hoverIndex && hoverClientY > hoverMiddleY) return;

      moveItem(dragIndex, hoverIndex);
      item.index = hoverIndex;
    }
  });

  //
  // DRAG SOURCE
  //
  const [{ isDragging }, drag] = useDrag<DragItem, void, DragCollected>({
    type: ItemType,
    item: { id: story.id, index, type: ItemType },

    end: (item, monitor) => {
      if (!monitor.didDrop()) return;

      // Use the index that was updated during hover, not getCurrentPosition
      updatePosition(item.id, item.index);
    },

    collect: monitor => ({
      isDragging: monitor.isDragging()
    })
  });

  // Attach drag + drop handlers
  drag(drop(ref));

  const pathHelper = useMemo(() => new PathHelperService(), []);

  //
  // EDITING STATE
  //
  const [isEditing, setIsEditing] = useState(false);

  const [formValues, setFormValues] = useState({
    type_id: story.type_id,
    subject: story.subject,
    status_id: story.status_id,
    story_points: story.story_points ?? 0
  });

  // Reset when story changes from parent
  useEffect(() => {
    setFormValues({
      type_id: story.type_id,
      subject: story.subject,
      status_id: story.status_id,
      story_points: story.story_points ?? 0
    });
  }, [story]);

  const handleInputChange = (
    field:keyof Story,
    value:Story[keyof Story]
  ) => {
    setFormValues(current => ({
      ...current,
      [field]: value
    }));
  };

  const [backlogsQuery, typesQuery, statusesQuery] = useProjectQueries(projectIdentifier);
  const { mutate, error, isSuccess } = useSubmitForm(projectIdentifier, sprintId.toString(), story.id.toString());

  const isLoading =
    backlogsQuery.isPending ||
    typesQuery.isPending ||
    statusesQuery.isPending;

  const isError =
    backlogsQuery.error ||
    typesQuery.error ||
    statusesQuery.error;

  if (isLoading) return 'Loading...';

  if (isError) {
    return (
      'Error: ' +
      (backlogsQuery.error?.message ||
        typesQuery.error?.message ||
        statusesQuery.error?.message)
    );
  }

  const handleSave = () => {
    mutate({
      type_id: formValues.type_id,
      subject: formValues.subject,
      status_id: formValues.status_id,
      story_points: formValues.story_points
    });
    setIsEditing(false);
  };

  const handleCancel = () => {
    setFormValues({
      type_id: story.type_id,
      subject: story.subject,
      status_id: story.status_id,
      story_points: story.story_points ?? 0
    });
    setIsEditing(false);
  };

  //
  // RENDER
  //


  if (isEditing) {
    return (
      <form>
        <Stack direction='horizontal' align='center' gap="condensed"> 
         <Stack.Item shrink={false}>
            <TypeSelect 
              projectId={projectId.toString()} 
              selectedId={formValues.type_id}
              onSelectedIdChange={(selectedId) => {  handleInputChange('type_id', selectedId); }}
            ></TypeSelect>
          </Stack.Item>
          <Stack.Item grow={true}>
            <InlineTextField 
              value={formValues.subject}
              onChange={(event) => handleInputChange('subject', event.target.value)}
            ></InlineTextField>
          </Stack.Item>
          <Stack.Item shrink={false}>
            <StatusSelect
              selectedId={formValues.status_id}
              onSelectedIdChange={(selectedId) => {  handleInputChange('status_id', selectedId);}}
            ></StatusSelect>
          </Stack.Item>
          <Stack.Item>
            <InlineTextField 
              type="number"
              value={formValues.story_points.toString()}
              onChange={(event) => handleInputChange('story_points', event.target.value)}
            ></InlineTextField> 
          </Stack.Item>
          <div className='op-border-box-grid--row-action'>
            <div className="d-flex gap-2">
              <IconButton icon={CheckIcon}  onClick={handleSave} variant="primary" aria-label="Save" />
              <IconButton icon={UndoIcon} aria-label="Cancel" onClick={handleCancel} />
            </div>
          </div>
        </Stack>
      </form>
    );
  }

  return (
    <div ref={ref} style={{ opacity: isDragging ? 0.4 : 1, cursor: 'move' }}>
       <Stack direction='horizontal' align='center' gap="condensed"> 
        <Stack.Item shrink={false}>
          <Link href={pathHelper.workPackagePath(story.id)}>#{story.id}</Link>
        </Stack.Item>
        <Stack.Item shrink={false}>
          <Text as="span" weight="semibold" className={`__hl_inline_type_${story.type_id}`}>
            {story.type?.name}
          </Text>
        </Stack.Item>
        <Stack.Item grow={true}>{story.subject}</Stack.Item>
        <Stack.Item>
          <Label className={`__hl_background_status_${story.status_id}`}>{story.status?.name}</Label>
        </Stack.Item>
        <Stack.Item>
          <CounterLabel>{story.story_points}</CounterLabel>
        </Stack.Item>
        
        <IconButton variant="invisible" icon={PencilIcon} aria-label="Edit" onClick={() => setIsEditing(true)} />
        <StoryMenu/>
      </Stack>
    </div>
  );
}
