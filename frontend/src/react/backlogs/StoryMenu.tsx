import { ChevronDownIcon, ChevronUpIcon, KebabHorizontalIcon, MoveToBottomIcon, MoveToTopIcon } from '@primer/octicons-react';
import { ActionList, ActionMenu, IconButton } from '@primer/react';

interface StoryMenuProps {

}

export function StoryMenu({  }:StoryMenuProps) {
  return (
    <ActionMenu>
      <ActionMenu.Anchor>
        <IconButton icon={KebabHorizontalIcon} aria-label="Open menu" variant='invisible' />
      </ActionMenu.Anchor>
      <ActionMenu.Overlay width="small">
        <ActionList>
          <ActionList.Item>
            <ActionList.LeadingVisual>
              <MoveToTopIcon />
            </ActionList.LeadingVisual>
            Move to top
          </ActionList.Item>
          <ActionList.Item>
            <ActionList.LeadingVisual>
              <ChevronUpIcon />
            </ActionList.LeadingVisual>
            Move up
          </ActionList.Item>
          <ActionList.Item>
            <ActionList.LeadingVisual>
              <ChevronDownIcon />
            </ActionList.LeadingVisual>
            Move down
          </ActionList.Item>
          <ActionList.Item>
            <ActionList.LeadingVisual>
              <MoveToBottomIcon />
            </ActionList.LeadingVisual>
            Move to bottom
          </ActionList.Item>
        </ActionList>
      </ActionMenu.Overlay>
    </ActionMenu>
  );
}
