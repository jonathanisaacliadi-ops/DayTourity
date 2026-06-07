import { Module } from '@nestjs/common';
import { ToursController } from './tours.controller';
import { ToursService } from './tours.service';
import { ToursRepository } from './tours.repository';
import { PricingCategoryService } from './pricing/pricing-category.service';

@Module({
  controllers: [ToursController],
  providers: [ToursService, ToursRepository, PricingCategoryService],
  exports: [ToursService],
})
export class ToursModule {}
