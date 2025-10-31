import { ID } from '@datorama/akita';

export interface IProjectData {
  id:ID;
  href:string;
  identifier:string;
  name:string;
  disabled:boolean;
  children:IProjectData[];
  position:number;
}
