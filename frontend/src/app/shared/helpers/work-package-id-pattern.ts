/**
 * URL-safe pattern that matches work package identifiers:
 * numeric IDs ("123") and semantic identifiers ("PROJ-42").
 *
 * Used in UI Router route definitions so that both forms are accepted in URLs.
 * The backend equivalent lives in WorkPackage::SemanticIdentifier::ID_ROUTE_CONSTRAINT.
 */
export const WP_ID_URL_PATTERN = '\\d+|[A-Za-z][A-Za-z0-9_]*-\\d+';
