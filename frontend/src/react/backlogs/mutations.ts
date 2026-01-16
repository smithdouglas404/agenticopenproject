import { useMutation, useQueryClient } from '@tanstack/react-query';
import { getMetaContent } from 'core-app/core/setup/globals/global-helpers';
import { useEffect, useState } from 'react';
import { Backlog, Story, Task } from './queries';


function useMetaContent(name:string) {
  const [value, setValue] = useState('');

  useEffect(() => { setValue(getMetaContent(name)); }, [name]);

  return value;
}

export function useSubmitForm(projectIdentifier:string, sprintId:string, storyId:string) {
  const csrfToken = useMetaContent('csrf-token');
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (formData:Partial<Story>) => {
      const response = await fetch(`/projects/${projectIdentifier}/sprints/${sprintId}/stories/${storyId}.json`, {
        method: 'PATCH',
        headers: { 
          'Content-Type': 'application/json',
          'X-Authentication-Scheme': 'Session',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(formData),
      });

      if (!response.ok) {
        throw new Error('Failed to submit');
      }

      return response.json();
    },
    onSuccess: () => {
      // Invalidate and refetch
      queryClient.invalidateQueries({ queryKey: ['backlogs', projectIdentifier] });
    },
  });
}

export function useSubmitForm2(projectIdentifier:string, sprintId:string|number) {
   const csrfToken = useMetaContent('csrf-token');
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (story:Partial<Story> & { id:string|number}) => {
      const response = await fetch(`/projects/${projectIdentifier}/sprints/${sprintId}/stories/${story.id}.json`, {
        method: 'PATCH',
        headers: { 
          'Content-Type': 'application/json',
          'X-Authentication-Scheme': 'Session',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(story),
      });

      if (!response.ok) {
        throw new Error('Failed to submit');
      }

      return response.json();
    },
    onSuccess: () => {
      // Invalidate and refetch
      queryClient.invalidateQueries({ queryKey: ['backlogs', projectIdentifier] });
    },
  });
}

export interface TaskFormData {
  subject:string;
  assigned_to_id?:number;
  remaining_hours:number|null;
  parent_id:number;
}

export function useCreateTask(projectIdentifier:string, sprintId:string) {
  const csrfToken = useMetaContent('csrf-token');
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (formData:TaskFormData) => {
      const response = await fetch(`/projects/${projectIdentifier}/sprints/${sprintId}/tasks`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Authentication-Scheme': 'Session',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(formData),
      });

      if (!response.ok) {
        throw new Error('Failed to create task');
      }

      return response.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['taskboard', projectIdentifier, sprintId] });
    },
  });
}

export function useUpdateTask(projectIdentifier:string, sprintId:string) {
  const csrfToken = useMetaContent('csrf-token');
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (formData:Partial<TaskFormData> & { id:number }) => {
      const response = await fetch(`/projects/${projectIdentifier}/sprints/${sprintId}/tasks/${formData.id}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-Authentication-Scheme': 'Session',
          'X-CSRF-Token': csrfToken
        },
        body: JSON.stringify(formData),
      });

      if (!response.ok) {
        throw new Error('Failed to update task');
      }

      return response.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['taskboard', projectIdentifier, sprintId] });
    },
  });
}
