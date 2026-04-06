export class ApiError extends Error {
  constructor(
    public status:number,
    public body:unknown,
  ) {
    const message =
      typeof body === 'object' && body !== null && 'message' in body
        ? String((body as Record<string, unknown>).message)
        : `API error ${status}`;
    super(message);
    this.name = 'ApiError';
  }
}

function csrfToken():string | null {
  const meta = document.querySelector('meta[name="csrf-token"]');
  return meta ? meta.getAttribute('content') : null;
}

export async function apiFetch<T>(
  path:string,
  options:RequestInit = {},
):Promise<T> {
  const token = csrfToken();
  const headers:Record<string, string> = {
    Accept: 'application/hal+json',
    ...((options.body != null) && { 'Content-Type': 'application/json' }),
    ...(token && { 'X-CSRF-Token': token }),
  };

  const response = await fetch(`/api/v3${path}`, {
    ...options,
    headers: {
      ...headers,
      ...(options.headers as Record<string, string> ?? {}),
    },
    credentials: 'same-origin',
  });

  if (!response.ok) {
    const body:unknown = await response.json().catch(() => null);
    throw new ApiError(response.status, body);
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return response.json() as Promise<T>;
}
