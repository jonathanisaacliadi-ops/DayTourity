import { Injectable } from '@nestjs/common';

export type PriceCategory = 'BUDGET' | 'STANDARD' | 'PREMIUM' | 'OUTLIER';

export interface PriceThresholds {
  q1: number;
  q3: number;
  iqr: number;
  lowerFence: number;
  upperFence: number;
}

@Injectable()
export class PricingCategoryService {
  computeThresholds(prices: number[]): PriceThresholds | null {
    if (prices.length < 4) return null;

    const sorted = [...prices].sort((a, b) => a - b);
    const q1 = this.percentile(sorted, 25);
    const q3 = this.percentile(sorted, 75);
    const iqr = q3 - q1;

    return {
      q1,
      q3,
      iqr,
      lowerFence: q1 - 1.5 * iqr,
      upperFence: q3 + 1.5 * iqr,
    };
  }

  categorise(price: number, thresholds: PriceThresholds): PriceCategory {
    if (price > thresholds.upperFence) return 'OUTLIER';
    if (price > thresholds.q3) return 'PREMIUM';
    if (price > thresholds.q1) return 'STANDARD';
    return 'BUDGET';
  }

  preferenceToCategories(
    preference: 'BUDGET' | 'STANDARD' | 'PREMIUM',
  ): PriceCategory[] {
    const map: Record<string, PriceCategory[]> = {
      BUDGET: ['BUDGET'],
      STANDARD: ['STANDARD'],
      PREMIUM: ['PREMIUM', 'OUTLIER'],
    };
    return map[preference];
  }

  private percentile(sorted: number[], p: number): number {
    const index = (p / 100) * (sorted.length - 1);
    const lower = Math.floor(index);
    const upper = Math.ceil(index);
    const weight = index - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }
}
