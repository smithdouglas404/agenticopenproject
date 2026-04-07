import { ApiError } from '../api/client';
import {
  extractBoardErrorMessage,
  showBoardError,
} from './board-error';

describe('board error helpers', () => {
  const originalOpenProject = window.OpenProject;

  afterEach(() => {
    window.OpenProject = originalOpenProject;
  });

  it('extracts the backend message from ApiError bodies', () => {
    const error = new ApiError(422, {
      message: 'Status is invalid because no valid transition exists from old to new status for the current user\'s roles.',
    });

    expect(extractBoardErrorMessage(error, 'Card could not be moved.'))
      .toBe('Status is invalid because no valid transition exists from old to new status for the current user\'s roles.');
  });

  it('surfaces the extracted message through the OpenProject toast service', async () => {
    const addError = jasmine.createSpy('addError');
    window.OpenProject = {
      getPluginContext: jasmine.createSpy('getPluginContext').and.resolveTo({
        services: {
          notifications: {
            addError,
          },
        },
      }),
    } as never;

    const error = new ApiError(422, {
      message: 'Status is invalid because no valid transition exists from old to new status for the current user\'s roles.',
    });

    await showBoardError(error, 'Card could not be moved.');

    expect(addError).toHaveBeenCalledOnceWith(
      'Status is invalid because no valid transition exists from old to new status for the current user\'s roles.',
    );
  });
});
