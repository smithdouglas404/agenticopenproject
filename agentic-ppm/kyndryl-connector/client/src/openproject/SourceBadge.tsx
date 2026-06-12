/**
 * SourceBadge — "⚡ OpenProject" provenance chip for the Kyndral-365 DOSv2 client.
 *
 * Drop next to any entity title (task row, WBS node, project header). Renders
 * NOTHING for entities that aren't OpenProject-sourced, so it is safe to place
 * unconditionally:  <h2>{task.name} <SourceBadge entity={task} entityType="task" /></h2>
 *
 * - Tooltip (native `title`, no tooltip-lib dependency): "Synced from
 *   OpenProject — source of record. Last sync <relative time>."
 * - External-link icon = inline SVG (no icon-lib dependency).
 * - Tailwind only, dark-mode friendly (blue-500/10 surface, blue-600/300 text).
 *
 * ASSUMPTION: synced entities carry sourceSystem ('openproject'), externalId,
 * lastSyncedAt (see useOpenProject.ts header).
 *
 * DROP-IN: copy to <kyndral>/client/src/openproject/SourceBadge.tsx
 */
import type { ReactElement } from "react";
import {
  formatRelativeTime,
  isOpenProjectEntity,
  useOpenProjectLink,
  type OpenProjectEntity,
} from "./useOpenProject";

export interface SourceBadgeProps {
  /** Any entity — the badge self-gates via isOpenProjectEntity(). */
  entity: unknown;
  /**
   * Connector entity type for the deep link ('project' | 'epic' | 'feature' |
   * 'story' | 'task' | 'issue' | 'milestone' …). Falls back to
   * entity.entityType when omitted; without either, the chip renders with no
   * external link.
   */
  entityType?: string;
  className?: string;
}

/** Inline external-link icon (Lucide "external-link" path, no dependency). */
function ExternalLinkIcon({ className }: { className?: string }): ReactElement {
  return (
    <svg
      className={className}
      width="12"
      height="12"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d="M15 3h6v6" />
      <path d="M10 14 21 3" />
      <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
    </svg>
  );
}

export function SourceBadge({ entity, entityType, className }: SourceBadgeProps): ReactElement | null {
  const op: OpenProjectEntity | null = isOpenProjectEntity(entity) ? entity : null;
  const resolvedType: string | null = entityType ?? op?.entityType ?? null;
  // Hook is called unconditionally (rules of hooks); it skips fetching when
  // given nulls, so non-OP entities cost nothing.
  const { url } = useOpenProjectLink(op !== null ? resolvedType : null, op?.externalId ?? null);

  if (op === null) return null;

  const tooltip = `Synced from OpenProject — source of record. Last sync ${formatRelativeTime(op.lastSyncedAt)}.`;

  return (
    <span
      title={tooltip}
      className={
        "inline-flex items-center gap-1 rounded-full border border-blue-500/20 " +
        "bg-blue-500/10 px-2 py-0.5 text-[11px] font-medium leading-4 " +
        "text-blue-600 dark:text-blue-300 " +
        (className ?? "")
      }
    >
      <span aria-hidden="true">⚡</span>
      <span>OpenProject</span>
      {url !== null ? (
        <a
          href={url}
          target="_blank"
          rel="noopener noreferrer"
          aria-label="Open in OpenProject"
          className="ml-0.5 inline-flex items-center text-blue-600/80 hover:text-blue-600 dark:text-blue-300/80 dark:hover:text-blue-300"
          onClick={(e) => e.stopPropagation()}
        >
          <ExternalLinkIcon />
        </a>
      ) : null}
    </span>
  );
}

export default SourceBadge;
