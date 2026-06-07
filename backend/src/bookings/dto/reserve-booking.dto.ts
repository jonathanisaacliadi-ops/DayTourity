import { IsDateString, IsOptional, IsString, IsUUID } from 'class-validator';


export class ReserveBookingDto {
  @IsUUID()
  tourId: string;

  @IsDateString()
  scheduledDate: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
