import { IsEnum, IsOptional } from 'class-validator';
import { TourStatus } from '@prisma/client';
 
export class GetMyToursQueryDto {
  @IsOptional()
  @IsEnum(TourStatus)
  status?: TourStatus;
}