export interface WpCardData {
  id:string;
  subject:string;
  typeName:string;
  typeId:string;
  projectIdentifier:string;
  assigneeName?:string;
  assigneeAvatarUrl?:string;
  storyPoints?:number;
  priorityName?:string;
  priorityId?:string;
  selected?:boolean;
  draggable?:boolean;
  isClosed?:boolean;
}
