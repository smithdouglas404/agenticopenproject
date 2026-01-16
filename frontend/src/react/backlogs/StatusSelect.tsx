
import { fetchStatuses } from './queries';
import { useQuery } from '@tanstack/react-query';
import SVGCircle from './SVGCircle';
import InlineSelect, { InlineSelectItemInput } from './InlineSelect';

interface StatusSelectProps {
    selectedId:number;
  onSelectedIdChange:((selected:number|undefined) => void)
}

export default function StatusSelect({ selectedId, onSelectedIdChange }:StatusSelectProps) {
  const { data: statuses } = useQuery({
    queryKey: ['statuses'],
    queryFn: fetchStatuses
  });

  if (!statuses) return <div>Loading...</div>;

  const elements = statuses?._embedded?.elements ?? [];
  const items = elements
    .slice()
    .sort((a, b) => a.position - b.position)
    .map((status):InlineSelectItemInput<number> => {
    return { id: status.id, text: status.name, leadingVisual: () => <SVGCircle fill={status.color} /> };
  });

  return (
    <InlineSelect items={items} selectedId={selectedId} onSelectedIdChange={onSelectedIdChange}></InlineSelect>
  );
}
