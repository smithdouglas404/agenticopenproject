import { BookIcon, ComposeIcon, GearIcon, GraphIcon, KebabHorizontalIcon, ProjectIcon, TasklistIcon } from '@primer/octicons-react';
import { ActionList, ActionMenu, IconButton } from '@primer/react';
import { useI18n } from '../hooks/useI18n';
import { useProjectIdentifier } from '../hooks/useProjectIdentifier';

interface BacklogMenuProps {
  sprintId:number;
  onNewStory:() => void;

}

export function BacklogMenu({ sprintId, onNewStory }:BacklogMenuProps) {
  const projectIdentifier = useProjectIdentifier();
  const { t } = useI18n();

  return (
    <ActionMenu>
      <ActionMenu.Anchor>
        <IconButton icon={KebabHorizontalIcon} aria-label="Open menu" />
      </ActionMenu.Anchor>
      <ActionMenu.Overlay width="small">
        <ActionList aria-label="Watch preference options">
          <ActionList.Item onClick={onNewStory}>
            <ActionList.LeadingVisual>
              <ComposeIcon />
            </ActionList.LeadingVisual>
           {t('js.new_story')}
          </ActionList.Item>
          <ActionList.LinkItem href={`/projects/${projectIdentifier}/sprints/${sprintId}/query`} data-turbo="false">
            <ActionList.LeadingVisual>
              <TasklistIcon />
            </ActionList.LeadingVisual>
            {t('js.stories_tasks')}
          </ActionList.LinkItem>
          <ActionList.LinkItem href={`/projects/${projectIdentifier}/sprints/${sprintId}/taskboard`}>
            <ActionList.LeadingVisual>
              <ProjectIcon />
            </ActionList.LeadingVisual>
           {t('js.task_board')}
          </ActionList.LinkItem>
          <ActionList.Item>
            <ActionList.LeadingVisual>
              <GraphIcon />
            </ActionList.LeadingVisual>
           {t('js.burndown_chart')}
          </ActionList.Item>
          <ActionList.LinkItem href={`/projects/${projectIdentifier}/sprints/${sprintId}/wiki/edit`}>
            <ActionList.LeadingVisual>
              <BookIcon />
            </ActionList.LeadingVisual>
           {t('js.wiki')}
          </ActionList.LinkItem>
          <ActionList.LinkItem href={'/versions/4/edit?back_url=%2Fprojects%2Fyour-scrum-project%2Fbacklogs&project_id=2'}>
            <ActionList.LeadingVisual>
              <GearIcon />
            </ActionList.LeadingVisual>
           {t('js.properties')}
          </ActionList.LinkItem>
        </ActionList>
      </ActionMenu.Overlay>
    </ActionMenu>
  );
}


