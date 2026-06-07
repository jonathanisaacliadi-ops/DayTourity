import { IsEnum } from 'class-validator';
import { PricePreference } from '@prisma/client';

export class UpdatePreferencesDto {
  @IsEnum(PricePreference)
  pricePreference: PricePreference;
}
