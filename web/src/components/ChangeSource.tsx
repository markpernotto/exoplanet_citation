import type { ChangeRecord, ValueReference } from '../api';

// The citation behind a change event's reported value: the new value's
// reference, or the removed value's for REMOVED. When NASA switched a
// parameter to a different source, the previous one is shown as "was".
// Discovery-paper references (NEW / REMOVED and the disc_* fields) are
// labelled as such, because NASA gives no separate source for a
// reclassification and the paper did not necessarily make the change.

function RefLink({ r }: { r: ValueReference }) {
  const label = r.kind === 'calculated' ? 'calculated by NASA Exoplanet Archive' : r.label;
  return r.url
    ? <a href={r.url} target="_blank" rel="noopener noreferrer">{label}</a>
    : <>{label}</>;
}

export default function ChangeSource({ change, compact = false }: { change: ChangeRecord; compact?: boolean }) {
  const shown = change.change_type === 'REMOVED' ? change.prev_ref : change.new_ref;
  const previous = change.change_type === 'PARAMETER_CHANGE' ? change.prev_ref : null;
  const switched = !!previous && previous.label !== shown?.label;

  if (!shown) {
    return <span style={{ color: 'var(--fg-muted)' }}>{compact ? 'no source given' : 'No source given by NASA Exoplanet Archive'}</span>;
  }
  const prefix = shown.role === 'discovery' ? 'discovery reference: ' : compact ? 'per ' : 'source: ';
  return (
    <span>
      {prefix}<RefLink r={shown} />
      {switched && !compact && <span style={{ color: 'var(--fg-muted)' }}> (was <RefLink r={previous} />)</span>}
    </span>
  );
}
