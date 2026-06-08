import { Injectable } from '@nestjs/common';
import { Prisma, TourStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const bookingSummaryInclude = {
  tour: {
    select: { id: true, title: true, city: true, coverImageUrl: true },
  },
  guide: {
    select: { id: true, name: true, phone: true },
  },
};
const guideBookingInclude = {
  tour: {
    select: { id: true, title: true, city: true, coverImageUrl: true },
  },
  traveller: {
    select: { id: true, name: true },
  },
};

@Injectable()
export class BookingsRepository {
  constructor(private readonly prisma: PrismaService) {}

  findConversationWithBooking(conversationId: string) {
    return this.prisma.conversation.findUnique({
      where: { id: conversationId },
      include: { booking: true },
    });
  }

  createBooking(data: Prisma.BookingUncheckedCreateInput) {
    return this.prisma.booking.create({
      data,
      include: bookingSummaryInclude,
    });
  }

  findManyByTraveller(travellerId: string, statusFilter: TourStatus[]) {
    return this.prisma.booking.findMany({
      where: {
        travellerId,
        status: { in: statusFilter },
      },
      orderBy: [{ status: 'asc' }, { scheduledDate: 'asc' }],
      include: bookingSummaryInclude,
    });
  }

  findManyByGuide(guideId: string) {
    return this.prisma.booking.findMany({
      where: { guideId },
      orderBy: [{ status: 'asc' }, { scheduledDate: 'asc' }],
      include: guideBookingInclude,
    });
  }

  findActiveByTourAndTraveller(tourId: string, travellerId: string) {
    return this.prisma.booking.findFirst({
      where: {
        tourId,
        travellerId,
        status: { in: [TourStatus.PLANNED, TourStatus.ONGOING] },
      },
    });
  }

  findBookingById(bookingId: string) {
    return this.prisma.booking.findUnique({ where: { id: bookingId } });
  }

  updateStatus(
    bookingId: string,
    data: Prisma.BookingUncheckedUpdateInput,
  ) {
    return this.prisma.booking.update({
      where: { id: bookingId },
      data,
    });
  }
}
