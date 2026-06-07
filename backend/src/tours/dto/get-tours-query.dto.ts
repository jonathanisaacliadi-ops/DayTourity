import { IsEnum, IsOptional, IsString } from 'class-validator';

export enum PriceCategoryFilter {
  BUDGET = 'BUDGET',
  STANDARD = 'STANDARD',
  PREMIUM = 'PREMIUM',
}

export class GetToursQueryDto {
  @IsString()
  @IsOptional()
  city?: string;

  @IsEnum(PriceCategoryFilter)
  @IsOptional()
  priceCategory?: PriceCategoryFilter;
}
