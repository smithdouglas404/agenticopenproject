const OPENPROJECT_DIRECT_URL = process.env.OPENPROJECT_DIRECT_URL;
if (OPENPROJECT_DIRECT_URL) {
  const openProjectDirectUrl = new URL(OPENPROJECT_DIRECT_URL);
  if (!openProjectDirectUrl.protocol || !openProjectDirectUrl.hostname) {
    throw new Error(`Invalid OPENPROJECT_DIRECT_URL: ${OPENPROJECT_DIRECT_URL}`);
  }

  console.log(`using OPENPROJECT_DIRECT_URL: ${OPENPROJECT_DIRECT_URL}`);
}

export function shouldReplaceHost():boolean {
  return !!OPENPROJECT_DIRECT_URL;
}

/**
 * Replaces the hostname of the given resource URL with the explicit host
 * if a direct hostname is defined
 */
export function replaceWithExplicitHost(resourceUrl:string):string {
  if (!OPENPROJECT_DIRECT_URL) {
    return resourceUrl;
  }

  const baseUrl = new URL(OPENPROJECT_DIRECT_URL);
  const resourcePath = new URL(resourceUrl).pathname;

  if (baseUrl.pathname.endsWith('/') && resourcePath.startsWith('/')) {
    baseUrl.pathname += resourcePath.slice(1);
  } else {
    baseUrl.pathname += resourcePath;
  }

  return baseUrl.toString();
}
