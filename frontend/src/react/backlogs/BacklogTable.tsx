import { useCallback, useEffect, useState } from 'react';
import { StoryExpanded, useProjectQueries, Backlog } from './queries';
import { StoryRow } from './StoryRow';
import { BacklogHeader} from './BacklogHeader';
import { useSubmitForm2 } from './mutations';
import { useProjectIdentifier } from '../hooks/useProjectIdentifier';



// <pre>{JSON.stringify(backlogsQuery.data, null, 2)}</pre>
export interface BacklogProps {
  backlog:Backlog
}

export function BacklogTable({backlog}:BacklogProps) {
  const projectIdentifier = useProjectIdentifier();
  const [_, typesQuery, statusesQuery] = useProjectQueries(projectIdentifier);
  const types = typesQuery.data?._embedded.elements ?? [];
  const statuses = statusesQuery.data?._embedded.elements ?? [];
  const [stories, setStories] = useState<StoryExpanded[]>([]);
  const { mutate, error, isSuccess } = useSubmitForm2(projectIdentifier, backlog.sprint.id);

  useEffect(() => {
    if (!types.length || !statuses.length) return;

    const expanded = backlog.stories.map((story):StoryExpanded => {
      const type = types.find((t) => t.id === story.type_id)!;
      const status = statuses.find((s) => s.id === story.status_id)!;
      return { ...story, type, status };
    });

    // Sort by position before storing
    setStories(expanded.sort((a, b) => a.position - b.position));
  }, [backlog.stories, types, statuses]);

  const totalPoints = stories
    .map((story) => story.story_points ?? 0)
    .reduce((accum, value) => accum + value, 0);

  const moveItem = useCallback((dragIndex:number, hoverIndex:number) => {
    setStories(prev => {
      const updated = [...prev].sort((a, b) => a.position - b.position);
      const [removed] = updated.splice(dragIndex, 1);
      updated.splice(hoverIndex, 0, removed);

      return updated.map((story, i) => ({ ...story, position: i }));
    });
  }, []);

  const getCurrentPosition = (id:number | string) => stories.find(s => s.id === id)?.position ?? 0;

  const updatePosition = (id:number|string, position:number) => {
    mutate({ id: Number(id), position });
  };

  return (
    <div className="position-relative Box Box--condensed" id={`backlog_${backlog.sprint.id}`}>
      <div className="Box-header color-fg-muted">
        <BacklogHeader backlog={backlog}></BacklogHeader>
      </div>
      {stories.length > 0 && (
        <ul className="stories">
          {stories.sort((a, b) => a.position - b.position).map((story, index) => {
            return (
              <li key={story.id} className="Box-row">
                <StoryRow
                  story={story}
                  projectId={backlog.sprint.project_id}
                  sprintId={backlog.sprint.id}
                  index={index}
                  moveItem={moveItem}
                  getCurrentPosition={getCurrentPosition}
                  updatePosition={updatePosition}
                ></StoryRow>
              </li>
            );
          })}
          ;
        </ul>
      )}
      {stories.length === 0 && <div className="Box-body">No content</div>}
    </div>
  );
}
