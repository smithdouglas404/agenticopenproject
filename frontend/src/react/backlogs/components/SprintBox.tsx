 
import { MouseEventHandler, useEffect, useRef, useState } from 'react';
import { CalendarIcon, ChevronRightIcon, KebabHorizontalIcon, PlayIcon } from '@primer/octicons-react';
import { ActionList, ActionMenu, Button, IconButton } from '@primer/react';
import {
  Collection,
  Sprint,
  useMetaContent,
  useMetaValue,
  WorkPackage,
  WorkPackageCard,
} from '../BacklogContainer';

export default function SprintBox(sprint:Sprint) {
  const csrfToken = useMetaContent('csrf-token');
  const projectId = useMetaValue('current_project', 'projectId');

  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);

  const [workPackages, setWorkPackages] = useState<WorkPackage[]>([]);

  const handleContextMenu:MouseEventHandler<HTMLElement> = (event) => {
    event.preventDefault();
    setOpen(true);
  };

  useEffect(() => {
    if (projectId) {
      const filters = JSON.stringify([
        { sprintId: { operator: '=', values: [String(sprint.id)] } },
      ]);

      void fetch(
        `/api/v3/projects/${projectId}/work_packages?filters=${encodeURIComponent(filters)}`,
        {
          method: 'GET',
          headers: {
            Accept: 'application/hal+json',
            'X-CSRF-Token': csrfToken,
          },
        },
      )
        .then((res) => res.json())
        .then((obj:Collection<WorkPackage>) => obj._embedded.elements)
        .then((workPackages) => setWorkPackages(workPackages));
    }
  }, [projectId, sprint.id]);

  return (
    <div
      id={`agile_sprint_${sprint.id}`}
      data-test-selector={`sprint-${sprint.id}`}
      className="Box Box--condensed"
    >
      <div id={`agile_sprint_${sprint.id}_header`} className="Box-header">
        <header id={`"backlogs-sprint-header-component-${sprint.id}`}>
          <div className="op-sprint-header">
            <div style={{ gridArea: 'collapsible' }} className="op-sprint-header--collapsible">
              <div
                id="collapsible-header-08dc083d-cb8e-4e80-a6b8-f4957de6d465"
                className="CollapsibleHeader CollapsibleHeader--multi-line"
              >
                <div
                  role="button"
                  tabIndex={0}
                  aria-controls={`agile_sprint_${sprint.id}_list`}
                  aria-expanded="true"
                  className="CollapsibleHeader-triggerArea"
                >
                  <div className="CollapsibleHeader-title-line">
                    <h3 className="Truncate CollapsibleHeader-title Box-title">
                      <span className="Truncate-text">{sprint.name}</span>
                    </h3>
                    <span
                      aria-label="2 stories in sprint"
                      aria-live="polite"
                      title="2"
                      className="Counter CollapsibleHeader-count Counter--primary mr-2"
                    >
                      2
                    </span>
                    <ChevronRightIcon></ChevronRightIcon>
                  </div>
                  <span className="CollapsibleHeader-description color-fg-subtle">
                    <span aria-live="polite" className="velocity color-fg-subtle mr-3">
                      16&nbsp;points
                    </span>
                    <span role="group" className="color-fg-subtle">
                      <CalendarIcon></CalendarIcon>
                      <time dateTime="2026-03-30">{sprint.startDate}</time>
                      &nbsp;–&nbsp;
                      <time dateTime="2026-04-10">{sprint.finishDate}</time>
                    </span>
                  </span>
                </div>
              </div>
            </div>
            <div style={{ gridArea: 'actions' }} className="op-sprint-header--actions">
              <Button leadingVisual={PlayIcon}>Start</Button>
            </div>
            <div style={{ gridArea: 'menu' }} className="op-sprint-header--menu">
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
          </div>
        </header>
      </div>

      <ul id={`agile_sprint_${sprint.id}-list`} aria-labelledby={`agile_sprint_${sprint.id}_header`} className="Box-list">
        {workPackages.map((workPackage) => (
          <li
            key={workPackage.id}
            className="Box-row Box-row--hover-blue Box-row--focus-gray Box-row--clickable Box-row--draggable"
          >
            <WorkPackageCard {...workPackage}></WorkPackageCard>
          </li>
        ))}
      </ul>
    </div>
  );
}
