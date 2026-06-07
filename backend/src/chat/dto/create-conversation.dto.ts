import { IsUUID } from 'class-validator';

export class CreateConversationDto {
  @IsUUID()
  tourId: string;

  @IsUUID()
  guideId: string;
}
