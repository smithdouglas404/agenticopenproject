import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get<{ protocol: string, host: string, id: string }>(':protocol://:host/api/v3/documents/:id', (request) => {
    if (!request.request.headers.get('Authorization') || request.params.id == '401') {
      return HttpResponse.json({}, { status: 401 });
    }

    if (request.request.headers.get('Content-type') != 'application/json') {
      return HttpResponse.json({}, { status: 415 });
    }

    if (request.params.id == '404') {
      return HttpResponse.text('foo', { status: 404 });
    }

    return HttpResponse.json({
      id: request.params.id,
      title: 'Some existing document',
      __echo: {
        url: request.request.url,
        hostHeader: request.request.headers.get('Host')
      }
    });
  }),
];
