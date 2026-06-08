import { Injectable, Logger } from '@nestjs/common';

const SOURCE_URL = 'https://open.er-api.com/v6/latest/IDR';
const CACHE_TTL_MS = 6 * 60 * 60 * 1000;

export interface ExchangeRates {
  base: string;
  rates: Record<string, number>;
  fetchedAt: string;
}

@Injectable()
export class ExchangeRatesService {
  private readonly logger = new Logger(ExchangeRatesService.name);
  private cache: ExchangeRates | null = null;
  private cacheExpiresAt = 0;

  async getRates(): Promise<ExchangeRates> {
    const now = Date.now();
    if (this.cache && now < this.cacheExpiresAt) {
      return this.cache;
    }

    try {
      const response = await fetch(SOURCE_URL);
      if (!response.ok) {
        throw new Error(`Exchange rate API responded with ${response.status}`);
      }

      const data = (await response.json()) as {
        result: string;
        rates?: Record<string, number>;
      };

      if (data.result !== 'success' || !data.rates) {
        throw new Error('Exchange rate API returned an unexpected payload');
      }

      this.cache = {
        base: 'IDR',
        rates: data.rates,
        fetchedAt: new Date().toISOString(),
      };
      this.cacheExpiresAt = now + CACHE_TTL_MS;
      return this.cache;
    } catch (error) {
      if (this.cache) {
        this.logger.warn(
          `Failed to refresh exchange rates, serving cached rates: ${error}`,
        );
        return this.cache;
      }
      throw error;
    }
  }
}
