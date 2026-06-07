import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const tourInclude = {
  activities: { orderBy: { order: 'asc' as const } },
  guide: { select: { id: true, name: true, email: true } },
  photos: { orderBy: { order: 'asc' as const } },
};

@Injectable()
export class ToursRepository {
  constructor(private readonly prisma: PrismaService) {}

  findManyActive(where: Prisma.TourWhereInput) {
    return this.prisma.tour.findMany({
      where,
      include: tourInclude,
      orderBy: { createdAt: 'desc' },
    });
  }

  findByIdWithDetails(id: string) {
    return this.prisma.tour.findUnique({
      where: { id },
      include: tourInclude,
    });
  }

  findById(id: string) {
    return this.prisma.tour.findUnique({ where: { id } });
  }

  create(data: Prisma.TourUncheckedCreateInput) {
    return this.prisma.tour.create({
      data,
      include: tourInclude,
    });
  }

  update(id: string, data: Prisma.TourUpdateInput) {
    return this.prisma.tour.update({
      where: { id },
      data,
      include: tourInclude,
    });
  }

  delete(id: string) {
    return this.prisma.tour.delete({ where: { id } });
  }

  findLastPhoto(tourId: string) {
    return this.prisma.tourPhoto.findFirst({
      where: { tourId },
      orderBy: { order: 'desc' },
    });
  }

  createPhoto(data: { tourId: string; url: string; order: number }) {
    return this.prisma.tourPhoto.create({ data });
  }

  findPhotoById(photoId: string) {
    return this.prisma.tourPhoto.findUnique({ where: { id: photoId } });
  }

  deletePhoto(photoId: string) {
    return this.prisma.tourPhoto.delete({ where: { id: photoId } });
  }
}
