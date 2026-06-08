import { IsEnum } from 'class-validator';
import { Currency } from '@prisma/client';

export class UpdateCurrencyDto {
  @IsEnum(Currency)
  currency: Currency;
}
