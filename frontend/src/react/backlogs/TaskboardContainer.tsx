import '@primer/primitives/dist/css/functional/themes/light.css';
import { Avatar, BaseStyles, ThemeProvider, Text, IconButton, CounterLabel } from '@primer/react';
import React, { useMemo, useState } from 'react';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import {
  QueryClient,
  QueryClientProvider,
} from '@tanstack/react-query';
import { Story, Task, Status, useProjectQueries, useTaskboardQueries, User } from './queries';
import { I18nProvider } from '../hooks/useI18n';
import { useProjectIdentifier } from '../hooks/useProjectIdentifier';
import TaskDialog, { TaskDialogFormData } from './TaskDialog';
import { useCreateTask } from './mutations';
import { PlusIcon } from '@primer/octicons-react';
import styles from './TaskboardContainer.module.css';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { Principal } from './Principal';

const queryClient = new QueryClient();

export default function TaskboardsContainer() {
  return (
    <I18nProvider>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider>
          <DndProvider backend={HTML5Backend}>
            <BaseStyles>
              <Taskboard />
            </BaseStyles>
          </DndProvider>
        </ThemeProvider>
      </QueryClientProvider>
    </I18nProvider>
  );
}

function Taskboard() {
  const projectIdentifier = useProjectIdentifier();
  const [_backlogsQuery, _typesQuery, statusesQuery] = useProjectQueries(projectIdentifier);
  const [taskboardQuery] = useTaskboardQueries(projectIdentifier, '4');
  const statuses = taskboardQuery.data?.statuses ?? [];
  const stories = taskboardQuery.data?.stories ?? [];

  const [isTaskDialogOpen, setIsTaskDialogOpen] = useState(false);
  const [selectedStoryId, setSelectedStoryId] = useState<number | null>(null);
  const createTaskMutation = useCreateTask(projectIdentifier, '4');

  const handleOpenNewTaskDialog = (storyId:number) => {
    setSelectedStoryId(storyId);
    setIsTaskDialogOpen(true);
  };

  const handleCloseTaskDialog = () => {
    setIsTaskDialogOpen(false);
    setSelectedStoryId(null);
  };

  const handleSaveTask = (formData:TaskDialogFormData) => {
    if (selectedStoryId === null) return;
    createTaskMutation.mutate(
      {
        ...formData,
        parent_id: selectedStoryId,
      },
      {
        onSuccess: () => {
          handleCloseTaskDialog();
        },
      }
    );
  };

  const isLoading = taskboardQuery.isPending || statusesQuery.isPending;
  const isError = taskboardQuery.error ?? statusesQuery.error;

  if (isLoading) return <div>Loading...</div>;

  if (isError) {
    return <div>Error: {taskboardQuery.error?.message ?? statusesQuery.error?.message}</div>;
  }

  const gridTemplateColumns = `280px 48px repeat(${statuses.length}, minmax(200px, 1fr))`;

  return (
    <>

      <div className={styles.Taskboard} style={{ gridTemplateColumns }}>
        {/* Header Row */}
        <div className={styles.HeaderRow}>
          <div className={styles.HeaderCell}>Story</div>
          <div className={styles.HeaderCell}></div>
          {statuses.map((status) => (
            <div key={status.id} className={styles.HeaderCell}>
              {status.name}
            </div>
          ))}
        </div>

        {/* Story Rows */}
        {stories.map((story) => (
          <StoryRow
            key={story.id}
            story={story}
            statuses={statuses}
            onAddTask={handleOpenNewTaskDialog}
          />
        ))}
      </div>

      <TaskDialog
        isOpen={isTaskDialogOpen}
        onClose={handleCloseTaskDialog}
        onSave={handleSaveTask}
        storyId={selectedStoryId ?? 0}
        projectId={projectIdentifier}
      />
    </>
  );
}

interface StoryRowProps {
  story:Story;
  statuses:Status[];
  onAddTask:(storyId:number) => void;
}

function StoryRow({ story, statuses, onAddTask }:StoryRowProps) {
  const tasksByStatusId = groupBy(story.tasks ?? [], 'status_id');

  return (
    <div className={styles.StoryRow}>
      <StoryCard story={story} />
      <div className={styles.AddCell}>
        <IconButton
          variant="invisible"
          icon={PlusIcon}
          aria-label="Add task"
          onClick={() => onAddTask(story.id)}
        />
      </div>
      {statuses.map((status) => (
        <TaskCell
          key={status.id}
          tasks={tasksByStatusId[status.id] ?? []}
          isClosed={status.isClosed}
        />
      ))}
    </div>
  );
}

interface StoryCardProps {
  story:Story;
}

function StoryCard({ story }:StoryCardProps) {
  return (
    <div className={styles.StoryCard}>
      <div className={styles.StoryHeader}>
        <span>Status: {story.status_id}</span>
        <span>#{story.id}</span>
      </div>
      <div className={styles.StorySubject}>{story.subject}</div>
      <div className={styles.StoryFooter}>
        <div className={styles.Assignee}>
          {story.assigned_to 
            ? <Principal id={story.assigned_to.id} name={story.assigned_to.name} /> 
            : <span className={styles.Unassigned}>Unassigned</span>}
        </div>
        {story.story_points !== undefined && story.story_points !== null && (
          <CounterLabel>{story.story_points}</CounterLabel>
        )}
      </div>
    </div>
  );
}

interface TaskCellProps {
  tasks:Task[];
  isClosed:boolean;
}

function TaskCell({ tasks, isClosed }:TaskCellProps) {
  const cellClassName = isClosed
    ? `${styles.TaskCell} ${styles.TaskCellClosed}`
    : styles.TaskCell;

  return (
    <div className={cellClassName}>
      {tasks.map((task) => (
        <TaskCard key={task.id} task={task} />
      ))}
    </div>
  );
}

interface TaskCardProps {
  task:Task;
}

function TaskCard({ task }:TaskCardProps) {
  return (
    <div className={styles.TaskCard}>
      <div className={styles.TaskHeader}>
        <span>#{task.id}</span>
        {task.remaining_hours !== null && <span>{task.remaining_hours}h</span>}
      </div>
      <div className={styles.TaskSubject}>{task.subject}</div>
      <div className={styles.TaskFooter}>
        {task.assigned_to ? (
          <div className={styles.Assignee}>
            <Principal id={task.assigned_to.id} name={task.assigned_to.name} />
          </div>
        ) : (
          <span className={styles.Unassigned}>Unassigned</span>
        )}
      </div>
    </div>
  );
}

function groupBy<T>(array:T[], key:keyof T):Record<string, T[]> {
  return array.reduce((groups:Record<string, T[]>, item) => {
    const groupKey = String(item[key]);
    if (!groups[groupKey]) {
      groups[groupKey] = [];
    }
    groups[groupKey].push(item);
    return groups;
  }, {});
}

