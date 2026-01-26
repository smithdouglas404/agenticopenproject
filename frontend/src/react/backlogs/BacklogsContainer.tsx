import '@primer/primitives/dist/css/functional/themes/light.css';
import { BaseStyles, ThemeProvider } from '@primer/react';
import React from 'react';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import {
  QueryClient,
  QueryClientProvider,
} from '@tanstack/react-query';
import { useProjectQueries } from './queries';
import { I18nProvider } from '../hooks/useI18n';
import { BacklogTable } from './BacklogTable';
import { Backlog } from './queries';
import { useProjectIdentifier } from '../hooks/useProjectIdentifier';

declare module 'react/jsx-runtime' {
namespace JSX {
  interface IntrinsicElements {
    'collapsible-header':React.DetailedHTMLProps<
      React.HTMLAttributes<HTMLElement>,
      HTMLElement
    > & {
      start?:string;
      end?:string;
    };

    'opce-principal':React.DetailedHTMLProps<
      React.HTMLAttributes<HTMLElement>,
      HTMLElement
    > & {
      hideName?:boolean;
    };
  }
}
 }

const queryClient = new QueryClient();

export default function BacklogsContainer() {
  return (
    <I18nProvider>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider>
          <DndProvider backend={HTML5Backend}>
          <BaseStyles>
            <Backlogs></Backlogs>
          </BaseStyles>
          </DndProvider>
        </ThemeProvider>
      </QueryClientProvider>
    </I18nProvider>
  );
}

function Backlogs() {
  const projectIdentifier = useProjectIdentifier();
  const [backlogsQuery, typesQuery, statusesQuery] = useProjectQueries(projectIdentifier);

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


  return (
    <>
    <a href="/projects/your-scrum-project/wiki">Home</a>
     <div className="d-flex flex-wrap gap-4" data-turbo="false">
       {
         backlogsQuery.data.owner_backlogs.map((backlog:Backlog) => {
           return (
             <div key={backlog.sprint.id} style={ {flex: '0 0 calc(50% - var(--base-size-24, 24px))'}}>
             <BacklogTable backlog={backlog}></BacklogTable>
             </div>
           );
         })
       }

       {
         backlogsQuery.data.sprint_backlogs.map((backlog:Backlog) => {
           return (
             <div key={backlog.sprint.id} style={ {flex: '0 0 calc(50% - var(--base-size-24, 24px))'}}>
             <BacklogTable backlog={backlog}></BacklogTable>
             </div>
           );
         })
       }
     </div>
    </>
  );
}

//op-border-box-grid
        // <BorderBoxHeading>Type</BorderBoxHeading>
        // <BorderBoxHeading>Subject</BorderBoxHeading>
        // <BorderBoxHeading>Status</BorderBoxHeading>
        // <BorderBoxHeading>Story points</BorderBoxHeading>

      // <!--
      //   <Blankslate>
      //     <Blankslate.Visual>
      //       <BookIcon size="medium" />
      //     </Blankslate.Visual>
      //     <Blankslate.Heading>Blankslate heading</Blankslate.Heading>
      //     <Blankslate.Description>Use it to provide information when no dynamic content exists.</Blankslate.Description>
      //   </Blankslate>
      // -->
