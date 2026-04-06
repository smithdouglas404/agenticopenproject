import { ApiError } from '../api/client';

export function extractBoardErrorMessage(
  error:unknown,
  fallback:string,
):string {
  if (error instanceof ApiError) {
    const message = typeof error.body === 'object'
      && error.body !== null
      && 'message' in error.body
      ? (error.body as { message?:unknown }).message
      : undefined;

    if (typeof message === 'string' && message !== '') {
      return message;
    }
  }

  if (error instanceof Error && error.message !== '') {
    return error.message;
  }

  if (typeof error === 'string' && error !== '') {
    return error;
  }

  return fallback;
}

export async function showBoardError(
  error:unknown,
  fallback:string,
):Promise<void> {
  const pluginContext = await window.OpenProject.getPluginContext();
  pluginContext.services.notifications.addError(
    extractBoardErrorMessage(error, fallback),
  );
}
