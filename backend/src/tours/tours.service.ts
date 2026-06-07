import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { ToursRepository } from './tours.repository';
import {
  PricingCategoryService,
  PriceCategory,
} from './pricing/pricing-category.service';
import { GetToursQueryDto } from './dto/get-tours-query.dto';
import { CreateTourDto } from './dto/create-tour.dto';
import { UpdateTourDto } from './dto/update-tour.dto';
import { Decimal } from '@prisma/client/runtime/library';

@Injectable()
export class ToursService {
  constructor(
    private readonly toursRepository: ToursRepository,
    private readonly pricingService: PricingCategoryService,
  ) {}

  async getRecommended(query: GetToursQueryDto) {
    const whereClause: Prisma.TourWhereInput = { isActive: true };
    if (query.city) {
      whereClause.city = { contains: query.city, mode: 'insensitive' };
    }

    const allTours = await this.toursRepository.findManyActive(whereClause);

    const toursWithPrice = allTours.map((tour) => ({
      ...tour,
      totalPrice: this.tourTotal(tour),
    }));

    const prices = toursWithPrice.map((t) => t.totalPrice);
    const thresholds = this.pricingService.computeThresholds(prices);

    const taggedTours = toursWithPrice.map((tour) => ({
      ...tour,
      priceCategory: thresholds
        ? this.pricingService.categorise(tour.totalPrice, thresholds)
        : ('STANDARD' as PriceCategory),
    }));

    let filtered = taggedTours;
    if (query.priceCategory) {
      const allowed = this.pricingService.preferenceToCategories(
        query.priceCategory,
      );
      filtered = taggedTours.filter((t) => allowed.includes(t.priceCategory));
    }

    return {
      tours: filtered.map((t) => this.serializeTour(t)),
      meta: {
        city: query.city ?? null,
        priceCategory: query.priceCategory ?? null,
        thresholds: thresholds
          ? {
              q1: thresholds.q1,
              q3: thresholds.q3,
              iqr: thresholds.iqr,
              upperFence: thresholds.upperFence,
            }
          : null,
      },
    };
  }

  async findById(id: string) {
    const tour = await this.toursRepository.findByIdWithDetails(id);

    if (!tour) throw new NotFoundException('Tour not found');

    return this.serializeTour({
      ...tour,
      totalPrice: this.tourTotal(tour),
      priceCategory: 'STANDARD' as PriceCategory,
    });
  }


  async create(guideId: string, dto: CreateTourDto) {
    const tour = await this.toursRepository.create({
      title: dto.title,
      description: dto.description,
      city: dto.city,
      basePrice: dto.basePrice ?? 0,
      coverImageUrl: dto.coverImageUrl,
      availableDates: dto.availableDates?.map((d) => new Date(d)) ?? [],
      guideId,
      activities: {
        create: dto.activities.map((act, idx) => ({
          name: act.name,
          description: act.description,
          pricingType: act.pricingType,
          fixedPrice: act.fixedPrice,
          minPrice: act.minPrice,
          maxPrice: act.maxPrice,
          order: act.order ?? idx,
        })),
      },
      photos: dto.photoUrls?.length
        ? {
            create: dto.photoUrls.map((url, idx) => ({
              url,
              order: idx,
            })),
          }
        : undefined,
    });

    return this.serializeTour({
      ...tour,
      totalPrice: this.tourTotal(tour),
      priceCategory: 'STANDARD' as PriceCategory,
    });
  }

  async updateTour(id: string, guideId: string, dto: UpdateTourDto) {
    const tour = await this.toursRepository.findById(id);
    if (!tour) throw new NotFoundException('Tour not found');
    if (tour.guideId !== guideId) {
      throw new ForbiddenException('You can only edit your own tours');
    }

    const updated = await this.toursRepository.update(id, {
      ...(dto.title !== undefined && { title: dto.title }),
      ...(dto.description !== undefined && { description: dto.description }),
      ...(dto.city !== undefined && { city: dto.city }),
      ...(dto.basePrice !== undefined && { basePrice: dto.basePrice }),
      ...(dto.coverImageUrl !== undefined && {
        coverImageUrl: dto.coverImageUrl,
      }),
      ...(dto.availableDates !== undefined && {
        availableDates: dto.availableDates.map((d) => new Date(d)),
      }),
      ...(dto.activities !== undefined && {
        activities: {
          deleteMany: {},
          create: dto.activities.map((act, idx) => ({
            name: act.name,
            description: act.description,
            pricingType: act.pricingType,
            fixedPrice: act.fixedPrice,
            minPrice: act.minPrice,
            maxPrice: act.maxPrice,
            order: act.order ?? idx,
          })),
        },
      }),
    });

    return this.serializeTour({
      ...updated,
      totalPrice: this.tourTotal(updated),
      priceCategory: 'STANDARD' as PriceCategory,
    });
  }

  async deleteTour(id: string, guideId: string): Promise<{ message: string }> {
    const tour = await this.toursRepository.findById(id);
    if (!tour) throw new NotFoundException('Tour not found');
    if (tour.guideId !== guideId) {
      throw new ForbiddenException('You can only delete your own tours');
    }
    await this.toursRepository.delete(id);
    return { message: 'Tour deleted successfully' };
  }


  async addPhoto(
    tourId: string,
    guideId: string,
    url: string,
  ) {
    const tour = await this.toursRepository.findById(tourId);
    if (!tour) throw new NotFoundException('Tour not found');
    if (tour.guideId !== guideId) {
      throw new ForbiddenException('You can only add photos to your own tours');
    }

    const lastPhoto = await this.toursRepository.findLastPhoto(tourId);
    const nextOrder = lastPhoto ? lastPhoto.order + 1 : 0;

    return this.toursRepository.createPhoto({ tourId, url, order: nextOrder });
  }


  async removePhoto(tourId: string, photoId: string, guideId: string) {
    const tour = await this.toursRepository.findById(tourId);
    if (!tour) throw new NotFoundException('Tour not found');
    if (tour.guideId !== guideId) {
      throw new ForbiddenException('You can only remove photos from your own tours');
    }

    const photo = await this.toursRepository.findPhotoById(photoId);
    if (!photo || photo.tourId !== tourId) {
      throw new NotFoundException('Photo not found');
    }

    await this.toursRepository.deletePhoto(photoId);
    return { message: 'Photo removed' };
  }


  private computeTourPrice(
    activities: {
      pricingType: string;
      fixedPrice: Decimal | null;
      minPrice: Decimal | null;
      maxPrice: Decimal | null;
    }[],
  ): number {
    return activities.reduce((sum, act) => {
      if (act.pricingType === 'FIXED') return sum + Number(act.fixedPrice ?? 0);
      const mid = (Number(act.minPrice ?? 0) + Number(act.maxPrice ?? 0)) / 2;
      return sum + mid;
    }, 0);
  }

  private tourTotal(tour: {
    basePrice: Decimal | null;
    activities: {
      pricingType: string;
      fixedPrice: Decimal | null;
      minPrice: Decimal | null;
      maxPrice: Decimal | null;
    }[];
  }): number {
    return Number(tour.basePrice ?? 0) + this.computeTourPrice(tour.activities);
  }

  private serializeTour(tour: any) {
    return {
      id: tour.id,
      title: tour.title,
      description: tour.description,
      city: tour.city,
      basePrice: tour.basePrice != null ? Number(tour.basePrice) : 0,
      coverImageUrl: tour.coverImageUrl ?? null,
      isActive: tour.isActive,
      availableDates: (tour.availableDates ?? []).map((d: Date) =>
        d instanceof Date ? d.toISOString() : d,
      ),
      photos: (tour.photos ?? []).map((p: any) => ({
        id: p.id,
        url: p.url,
        order: p.order,
      })),
      totalPrice: tour.totalPrice,
      priceCategory: tour.priceCategory,
      guide: tour.guide,
      activities: tour.activities.map((act: any) => ({
        id: act.id,
        name: act.name,
        description: act.description,
        pricingType: act.pricingType,
        fixedPrice: act.fixedPrice ? Number(act.fixedPrice) : null,
        minPrice: act.minPrice ? Number(act.minPrice) : null,
        maxPrice: act.maxPrice ? Number(act.maxPrice) : null,
        order: act.order,
      })),
      createdAt: tour.createdAt,
    };
  }
}
