import { useBoardContext } from '../context/BoardContext';

export function AddColumnAction() {
  const { permissions } = useBoardContext();

  if (!permissions.canManage) {
    return null;
  }

  return null;
}
