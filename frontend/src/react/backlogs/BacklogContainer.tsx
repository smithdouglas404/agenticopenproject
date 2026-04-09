/* eslint-disable @typescript-eslint/no-unused-vars */
import { QueryClient, QueryClientProvider, useQuery } from '@tanstack/react-query';
import { getMetaContent, getMetaValue } from 'core-app/core/setup/globals/global-helpers';
import { MouseEventHandler, useEffect, useRef, useState } from 'react';
import { ErrorBoundary, FallbackProps } from 'react-error-boundary';
import { GrabberIcon, KebabHorizontalIcon } from '@primer/octicons-react';
import { ActionList, ActionMenu, BaseStyles, CounterLabel, Heading, IconButton, ThemeProvider } from '@primer/react';
import SprintBox from './components/SprintBox';
import {
  draggable,
  dropTargetForElements,
  monitorForElements,
} from '@atlaskit/pragmatic-drag-and-drop/element/adapter';
import invariant from 'tiny-invariant';
import type { CleanupFn } from '@atlaskit/pragmatic-drag-and-drop/types';

export default function BacklogContainer() {
  return (
    <ThemeProvider>
      <BaseStyles>
        <BacklogInnerContainer />
      </BaseStyles>
    </ThemeProvider>
  );
}

export function useMetaContent(name:string) {
  const [value, setValue] = useState('');

  useEffect(() => {
    setValue(getMetaContent(name));
  }, [name]);

  return value;
}

export function useMetaValue(name:string, key:string) {
  const [value, setValue] = useState('');

  useEffect(() => {
    setValue(getMetaValue(name, key));
  }, [name, key]);

  return value;
}

export interface Collection<T> {
  _embedded:{
    elements:T[];
  };
}

export interface Sprint {
  _type:'Sprint';
  id:number;
  name:string;
  startDate:any;
  finishDate:any;
  createdAt:string;
  updatedAt:string;
  _links:Links;
}

export interface Links {
  self:Self;
  status:Status;
  definingWorkspace:DefiningWorkspace;
}

export interface Self {
  href:string;
  title:string;
}

export interface Status {
  href:string;
  title:string;
}

export interface DefiningWorkspace {
  href:string;
  title:string;
}

export interface WorkPackage {
  id:number;
  subject:string;
  storyPoints?:number | null;
  _links:{
    type:{ href:string; title:string };
    status:{ href:string; title:string };
  };
}

function getIdFromHref(href:string) {
  return href.split('/').reverse()[0];
}

function BacklogInnerContainer() {
  const csrfToken = useMetaContent('csrf-token');
  const projectId = useMetaValue('current_project', 'projectId');

  const [workPackages, setWorkPackages] = useState<WorkPackage[]>([]);
  const [sprints, setSprints] = useState<Sprint[]>([]);

  useEffect(() => {
    return monitorForElements({
      onDrop({ source, location }) {
        const destination = location.current.dropTargets[0];

        console.log('source', source);
        console.log('dest', destination);
      },
    });
  }, [workPackages]);

  useEffect(() => {
    if (projectId) {
      const filters = JSON.stringify([{ sprintId: { operator: '!*', values: [] } }]);

      void fetch(`/api/v3/projects/${projectId}/work_packages?filters=${encodeURIComponent(filters)}`, {
        method: 'GET',
        headers: {
          Accept: 'application/hal+json',
          'X-CSRF-Token': csrfToken,
        },
      })
        .then((res) => res.json())
        .then((obj:Collection<WorkPackage>) => obj._embedded.elements)
        .then((workPackages) => setWorkPackages(workPackages));

      void fetch(`/api/v3/projects/${projectId}/sprints`, {
        method: 'GET',
        headers: {
          Accept: 'application/hal+json',
          'X-CSRF-Token': csrfToken,
        },
      })
        .then((res) => res.json())
        .then((obj:Collection<Sprint>) => obj._embedded.elements)
        .then((sprints) => setSprints(sprints));
    }
  }, [projectId]);

  // const { isPending, error, data } = useQuery({
  //   queryKey: ['repoData'],
  //   queryFn: () =>
  //     fetch(`/api/v3/projects/${projectId}/work_packages`).then((res) =>
  //       res.json(),
  //     ),
  // });

  // if (isPending) return 'Loading...'

  // if (error) return 'An error has occurred: ' + error.message;

  return (
    <div className="op-sprint-planning-container">
      <div id="owner_backlogs_container" className="op-sprint-planning-lists">
        <Heading as="h3">
          Backlog
          <CounterLabel>{workPackages.length}</CounterLabel>
        </Heading>
        <div className="Box Box--condensed">
          <ul className="Box-list">
            {workPackages.map((workPackage) => (
              <WorkPackageListItem key={workPackage.id} {...workPackage}></WorkPackageListItem>
            ))}
          </ul>
        </div>
      </div>
      <div id="sprint_backlogs_container" className="op-sprint-planning-lists">
        <Heading as="h3">Sprints</Heading>
        {sprints.map((sprint) => (
          <SprintBox key={sprint.id} {...sprint} />
        ))}
      </div>
    </div>
  );
}

export function WorkPackageListItem(workPackage:WorkPackage) {
  const ref = useRef(null);
  const [isDraggedOver, setIsDraggedOver] = useState(false);

  useEffect(() => {
    const el = ref.current;
    invariant(el);

     
    return dropTargetForElements({
      element: el,
      onDragEnter: () => setIsDraggedOver(true),
      onDragLeave: () => setIsDraggedOver(false),
      onDrop: () => setIsDraggedOver(false),
    });
  }, []);

  return (
    <li
      ref={ref}
      style={{ backgroundColor: isDraggedOver ? 'yellow' : 'transparent' }}
      className="Box-row Box-row--hover-blue Box-row--focus-gray Box-row--clickable Box-row--draggable"
    >
      <WorkPackageCard {...workPackage}></WorkPackageCard>
    </li>
  );
}

export function WorkPackageCard({ id, subject, storyPoints, _links }:WorkPackage) {
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const ref = useRef<HTMLElement>(null);
  const [dragging, setDragging] = useState<boolean>(false); // NEW

  useEffect(() => {
    const el = ref.current;
    invariant(el);

     
    return draggable({
      element: el,
      onDragStart: () => setDragging(true),
      onDrop: () => setDragging(false),
    });
  }, []);

  const handleContextMenu:MouseEventHandler<HTMLElement> = (event) => {
    event.preventDefault();
    setOpen(true);
  };

  return (
    <article className="op-backlogs-story" onContextMenu={handleContextMenu} ref={ref}>
      <div style={{ gridArea: 'drag_handle' }} className="hide-when-print op-backlogs-story--drag_handle">
        <div
          role="button"
          tabIndex={0}
          aria-label="Move new"
          className="op-backlogs-story--drag_handle_button DragHandle"
        >
          <GrabberIcon size={16} />
        </div>
      </div>
      <div style={{ gridArea: 'info_line' }} className="op-backlogs-story--info_line">
        <div className="flex-wrap d-flex flex-row">
          <div className="mr-2">
            <span className={`__hl_inline_type_${getIdFromHref(_links.type.href)} text-small`}>
              {_links.type.title}
            </span>
          </div>
          <div className="mr-2">
            <a
              title="new"
              href="/projects/backlogs-project/work_packages/1619"
              className="Link text-small color-fg-muted"
            >
              #{id}
            </a>
          </div>
          <div>
            <span className={`Label __hl_background_status_${getIdFromHref(_links.status.href)} Label--inline`}>
              {_links.status.title}
            </span>
          </div>
        </div>
      </div>
      <div style={{ gridArea: 'points' }} className="op-backlogs-story--points">
        <span className="color-fg-subtle">
          {storyPoints ?? 0}
          <span className="op-backlogs-points-label"> points</span>
        </span>
      </div>
      <div style={{ gridArea: 'menu' }} className="op-backlogs-story--menu">
        <ActionMenu open={open} onOpenChange={setOpen} anchorRef={triggerRef}>
          <ActionMenu.Anchor>
            <IconButton
              ref={triggerRef}
              variant="invisible"
              icon={KebabHorizontalIcon}
              onClick={handleContextMenu}
              aria-label="Open menu"
            />
          </ActionMenu.Anchor>
          <ActionMenu.Overlay>
            <ActionList>
              <ActionList.Item
                onSelect={() => {
                  alert('Item one clicked');
                }}
              >
                Delete
              </ActionList.Item>
            </ActionList>
          </ActionMenu.Overlay>
        </ActionMenu>
      </div>
      <div style={{ gridArea: 'subject' }} className="op-backlogs-story--subject">
        <span className="text-semibold">{subject}</span>
      </div>
    </article>
  );
}
