import axios, { AxiosRequestConfig, AxiosResponse } from "axios";

const OPENPROJECT_URL = process.env.OPENPROJECT_URL?.trim() || null;
const OPENPROJECT_HOST = process.env.OPENPROJECT_HOST?.trim() || null;

if (OPENPROJECT_URL) {
  const openProjectDirectUrl = new URL(OPENPROJECT_URL);
  if (!openProjectDirectUrl.protocol || !openProjectDirectUrl.hostname) {
    throw new Error(`Invalid OPENPROJECT_DIRECT_URL: ${OPENPROJECT_URL}`);
  }

  console.log(`using OPENPROJECT_URL: ${OPENPROJECT_URL}`);
}

if (OPENPROJECT_HOST) {
  console.log(`using OPENPROJECT_HOST: ${OPENPROJECT_HOST}`);
}

/**
 * Fetches an OpenProject resource while automatically adjusting request URL and host header
 * based on the values of OPENPROJECT_URL and OPENPROJECT_HOST in the environment.
 * 
 * @param resourceUrl URL of OpenProject resource to fetch
 * @param oauthToken OAuth Bearer token to authenticate with
 * @param override Override request init params (e.g. method, headers)
 * @returns Http response
 */
export async function fetchResource(
  resourceUrl: string,
  oauthToken: string,
  override?: AxiosRequestConfig
): Promise<AxiosResponse> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${oauthToken}`,
    ...(OPENPROJECT_HOST && { "Host": OPENPROJECT_HOST })
  };

  const params = {
    url: overrideUrl(resourceUrl),
    method: 'GET',
    headers: headers,
    ...override,
    validateStatus: (status: number) => {
      return status < 500; // throw exception for internal server errors only, otherwise we check `response.status`
    }
  }

  console.log(`[${new Date().toISOString()}] ${params.method} ${resourceUrl}`);

  return axios(params);
}

/**
 * Get the effective OpenProject resource URL considering the values of
 * OPENPROJECT_URL and OPENPROJECT_HOST in the environment.
 * 
 * @param resourceUrl URL of OpenProject resource
 * @returns Either the given resource URL if no override has been configured, or the adjusted URL.
 */
function overrideUrl(resourceUrl: string): string {
  return OPENPROJECT_URL ? overrideBaseUrl(resourceUrl, OPENPROJECT_URL) : resourceUrl;
}

/**
 * Replaces the protocol and hostname of the given resource URL with those of the given overrideUrl.
 */
function overrideBaseUrl(resourceUrl:string, overrideUrl: string):string {
  const baseUrl = new URL(overrideUrl);
  const resourcePath = new URL(resourceUrl).pathname;

  if (baseUrl.pathname.endsWith('/') && resourcePath.startsWith('/')) {
    baseUrl.pathname += resourcePath.slice(1);
  } else {
    baseUrl.pathname += resourcePath;
  }

  return baseUrl.toString();
}
