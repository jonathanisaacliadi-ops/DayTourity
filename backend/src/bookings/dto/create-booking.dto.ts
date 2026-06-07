import { IsDateString, IsNotEmpty, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';
 
export class CreateBookingDto {
  @IsUUID()
  conversationId: string;
 
  @IsDateString()
  scheduledDate: string;
 
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  agreedPrice: number;
 
  @IsOptional()
  @IsString()
  notes?: string;
}