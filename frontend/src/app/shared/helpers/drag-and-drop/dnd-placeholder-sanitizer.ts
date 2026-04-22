export const DEFAULT_DND_PLACEHOLDER_STRIP_ATTRIBUTES = ['id', 'data-controller'];

const PLACEHOLDER_SELECTOR = '[data-dnd-placeholder]';
const PLACEHOLDER_STRIP_ATTRIBUTES_VALUE_SUFFIX = '-placeholder-strip-attributes-value';

export function sanitizeDndPlaceholder(source:HTMLElement, root:ParentNode = document):boolean {
  const placeholder = findDndPlaceholderForSource(source, root);

  if (!placeholder) {
    return false;
  }

  placeholderStripAttributesFor(source).forEach((attribute) => placeholder.removeAttribute(attribute));

  return true;
}

function findDndPlaceholderForSource(source:HTMLElement, root:ParentNode):HTMLElement|null {
  const sibling = source.nextElementSibling;

  if (sibling instanceof HTMLElement && sibling.matches(PLACEHOLDER_SELECTOR)) {
    return sibling;
  }

  if (source.parentElement) {
    const siblingPlaceholder = Array
      .from(source.parentElement.children)
      .find((element) => element !== source && element instanceof HTMLElement && element.matches(PLACEHOLDER_SELECTOR));

    if (siblingPlaceholder instanceof HTMLElement) {
      return siblingPlaceholder;
    }
  }

  const placeholder = root.querySelector(PLACEHOLDER_SELECTOR);

  return placeholder instanceof HTMLElement ? placeholder : null;
}

function placeholderStripAttributesFor(source:HTMLElement):string[] {
  const configuredAttributes = source
    .getAttributeNames()
    .find((attributeName) => attributeName.endsWith(PLACEHOLDER_STRIP_ATTRIBUTES_VALUE_SUFFIX));

  const configuredValue = configuredAttributes ? source.getAttribute(configuredAttributes) : null;
  const value = configuredValue?.trim();

  if (!value) {
    return DEFAULT_DND_PLACEHOLDER_STRIP_ATTRIBUTES;
  }

  return Array.from(new Set(value.split(/\s+/).filter(Boolean)));
}
