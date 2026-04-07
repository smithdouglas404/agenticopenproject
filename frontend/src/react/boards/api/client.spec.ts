import { apiFetch } from './client';

describe('apiFetch', () => {
  const originalFetch = window.fetch;

  afterEach(() => {
    window.fetch = originalFetch;
    document.head.innerHTML = '';
  });

  it('sends the authenticated OpenProject headers for write requests', async () => {
    const response = new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });

    document.head.innerHTML = '<meta name="csrf-token" content="csrf-123">';
    window.fetch = jasmine.createSpy('fetch').and.resolveTo(response);

    await apiFetch('/work_packages/33', {
      method: 'PATCH',
      body: JSON.stringify({ lockVersion: 7 }),
    });

    expect(window.fetch).toHaveBeenCalledOnceWith('/api/v3/work_packages/33', jasmine.objectContaining({
      method: 'PATCH',
      body: JSON.stringify({ lockVersion: 7 }),
      credentials: 'same-origin',
      headers: jasmine.objectContaining({
        Accept: 'application/hal+json',
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'X-CSRF-TOKEN': 'csrf-123',
      }),
    }));
  });
});
