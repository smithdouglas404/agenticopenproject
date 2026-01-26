import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { useMemo } from 'react';

interface PrincipalProps {
  id:number;
  name:string;
  hideName?:boolean;
}

export function Principal({ id, name, hideName }:PrincipalProps) {
  const pathHelper = useMemo(() => new PathHelperService(), []);
  const apiV3Base = pathHelper.api.v3.apiV3Base;

  return (
    <opce-principal 
      data-principal={JSON.stringify({ href: `${apiV3Base}/users/${id}`, name, id})}
      data-size={JSON.stringify('mini')}
      data-title={JSON.stringify(name)}
      data-link={JSON.stringify(pathHelper.userPath(id))}
      data-hover-card={JSON.stringify(true)}
      data-hide-name={JSON.stringify(hideName)}
    >
    </opce-principal>
  );
}
