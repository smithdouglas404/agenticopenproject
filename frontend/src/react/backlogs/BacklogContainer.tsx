/* eslint-disable @typescript-eslint/no-unused-vars */
import {
  QueryClient,
  QueryClientProvider,
  useQuery,
} from '@tanstack/react-query';
import { getMetaContent, getMetaValue } from 'core-app/core/setup/globals/global-helpers';
import { useEffect, useState } from 'react';
import { ErrorBoundary, FallbackProps } from 'react-error-boundary';
import {GrabberIcon, KebabHorizontalIcon} from '@primer/octicons-react';
import { ActionList, ActionMenu, BaseStyles, Button, IconButton, ThemeProvider } from '@primer/react';



export default function BacklogContainer() {
  return (
    <ThemeProvider>
      <BaseStyles>
      <BacklogInnerContainer /> 
      </BaseStyles>
    </ThemeProvider>
  );
}

function useMetaContent(name:string) {
  const [value, setValue] = useState('');

  useEffect(() => { setValue(getMetaContent(name)); }, [name]);

  return value;
}

function useMetaValue(name:string, key:string) {
  const [value, setValue] = useState('');

  useEffect(() => { setValue(getMetaValue(name, key)); }, [name, key]);

  return value;
}

interface Collection<T> {
  _embedded:{
    elements:T[]
  }
}

interface WorkPackage {
  id:number;
  subject:string;
  storyPoints?:number|null;
  _links:{
    type:{ href:string, title:string },
    status:{ href:string, title:string }
  }
}

function getIdFromHref(href:string) {
  return href.split('/').reverse()[0];
}

function BacklogInnerContainer() {
  const csrfToken = useMetaContent('csrf-token');
  const projectId = useMetaValue('current_project', 'projectId');

  const [workPackages, setWorkPackages] = useState<WorkPackage[]>([]);

  useEffect(() => {
    if (projectId) {
       void fetch(`/api/v3/projects/${projectId}/work_packages`, {
          method: 'GET',
          headers: {
              'Accept': 'application/hal+json',
              'X-CSRF-Token': csrfToken
          }
       })
        .then((res) => res.json())
        .then((obj:Collection<WorkPackage>) => obj._embedded.elements)
        .then((workPackages) => setWorkPackages(workPackages));
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
    <div className='op-sprint-planning-container'>
      <div id="owner_backlogs_container" className='op-sprint-planning-lists'>
        <div className="Box Box--condensed">
          <ul className='Box-list'>
            {workPackages.map((workPackage) => 
              <li key={workPackage.id} className='Box-row Box-row--hover-blue Box-row--focus-gray Box-row--clickable Box-row--draggable'>
                
                
                <WorkPackageCard  {...workPackage}></WorkPackageCard>
              </li>
            )}
          </ul>
        </div>
      </div>
    </div>
  );
}



function WorkPackageCard({ id, subject, storyPoints, _links }:WorkPackage) {
  return (
  <article className="op-backlogs-story">
    <div style={{'gridArea': 'drag_handle'}} className="hide-when-print op-backlogs-story--drag_handle">
        <div role="button" tabIndex={0} aria-label="Move new" className="op-backlogs-story--drag_handle_button DragHandle">
            <GrabberIcon size={16} />
        </div>
    </div>
        <div style={{'gridArea': 'info_line'}} className="op-backlogs-story--info_line">
        <div className="flex-wrap d-flex flex-row">
            <div className="mr-2"><span className={`__hl_inline_type_${getIdFromHref(_links.type.href)} text-small`}>{_links.type.title}</span></div>
            <div className="mr-2"><a title="new" href="/projects/backlogs-project/work_packages/1619"
                    className="Link text-small color-fg-muted">#{id}</a></div>
            <div><span className={`Label __hl_background_status_${getIdFromHref(_links.status.href)} Label--inline`}>{_links.status.title}</span>
            </div>
        </div>
    </div>
    <div style={{'gridArea': 'points'}} className="op-backlogs-story--points"> <span className="color-fg-subtle">
            {storyPoints ?? 0}
            <span className="op-backlogs-points-label"> points</span>
        </span></div>
    <div style={{'gridArea': 'menu'}} className="op-backlogs-story--menu">
      <ActionMenu>
        <ActionMenu.Anchor>
          <IconButton variant='invisible' icon={KebabHorizontalIcon} aria-label="Open menu" />
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
    <div style={{'gridArea': 'subject'}} className="op-backlogs-story--subject">
      <span className="text-semibold">{subject}</span>
    </div>
</article>
  );
}
