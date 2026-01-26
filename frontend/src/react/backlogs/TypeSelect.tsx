
import { fetchTypes } from './queries';
import { useQuery } from '@tanstack/react-query';
import InlineSelect, { InlineSelectItemInput } from './InlineSelect';

interface TypeSelectProps {
  projectId:string;
  selectedId:number;
  onSelectedIdChange:((selected:number|undefined) => void)
}

export default function TypeSelect({ projectId, selectedId, onSelectedIdChange }:TypeSelectProps) {
  const { data: types } = useQuery({
    queryKey: ['projectTypes', projectId],
    queryFn: () => fetchTypes(projectId),
  });

  if (!types) return <div>Loading...</div>;

  const elements = types?._embedded?.elements ?? [];
  const items = elements
    .slice()
    .sort((a, b) => a.position - b.position)
    .map((type):InlineSelectItemInput<number> => ({ id: type.id, text: type.name }));

  return (
    <InlineSelect items={items} selectedId={selectedId} onSelectedIdChange={onSelectedIdChange}></InlineSelect>
  );
}
