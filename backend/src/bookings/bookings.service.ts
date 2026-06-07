import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { TourStatus } from '@prisma/client';
import { BookingsRepository } from './bookings.repository';
import { CreateBookingDto } from './dto/create-booking.dto';
import { ReserveBookingDto } from './dto/reserve-booking.dto';
import { GetMyToursQueryDto } from './dto/get-my-tours-query.dto';
import { ToursService } from '../tours/tours.service';

const ACTIVE_STATUSES: TourStatus[] = [TourStatus.PLANNED, TourStatus.ONGOING];

@Injectable()
export class BookingsService {
  constructor(
    private readonly bookingsRepository: BookingsRepository,
    private readonly toursService: ToursService,
  ) {}

  async reserve(travellerId: string, dto: ReserveBookingDto) {
    const tour = await this.toursService.findById(dto.tourId);

    if (tour.guide.id === travellerId) {
      throw new ForbiddenException('You cannot reserve your own tour.');
    }

    const existing = await this.bookingsRepository.findActiveByTourAndTraveller(
      dto.tourId,
      travellerId,
    );
    if (existing) {
      throw new ConflictException(
        'You already have an active reservation for this tour.',
      );
    }

    return this.bookingsRepository.createBooking({
      tourId: dto.tourId,
      travellerId,
      guideId: tour.guide.id,
      scheduledDate: new Date(dto.scheduledDate),
      agreedPrice: tour.totalPrice,
      notes: dto.notes,
      status: TourStatus.PLANNED,
    });
  }

  async getGuideBookings(guideId: string) {
    const bookings = await this.bookingsRepository.findManyByGuide(guideId);
    return { data: bookings, total: bookings.length };
  }

  async cancelBooking(bookingId: string, travellerId: string) {
    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking not found.');
    if (booking.travellerId !== travellerId) {
      throw new ForbiddenException('This is not your reservation.');
    }
    if (booking.status !== TourStatus.PLANNED) {
      throw new ConflictException('Only upcoming reservations can be cancelled.');
    }

    const THREE_DAYS_MS = 3 * 24 * 60 * 60 * 1000;
    const msUntilTour = booking.scheduledDate.getTime() - Date.now();
    if (msUntilTour < THREE_DAYS_MS) {
      throw new ForbiddenException(
        'Cancellation is only allowed up to 3 days before the tour.',
      );
    }

    return this.bookingsRepository.updateStatus(bookingId, {
      status: TourStatus.CANCELLED,
    });
  }

  async createBooking(travellerId: string, dto: CreateBookingDto) {
    const conversation = await this.bookingsRepository.findConversationWithBooking(
      dto.conversationId,
    );

    if (!conversation) {
      throw new NotFoundException('Conversation tidak ditemukan.');
    }
    if (conversation.userId !== travellerId) {
      throw new ForbiddenException('Bukan conversation Anda.');
    }
    if (conversation.bookingStatus !== 'PAID') {
      throw new ConflictException('Conversation harus berstatus PAID sebelum booking dibuat.');
    }
    if (conversation.booking) {
      throw new ConflictException('Booking untuk conversation ini sudah ada.');
    }

    return this.bookingsRepository.createBooking({
      conversationId: dto.conversationId,
      tourId:         conversation.tourId,
      travellerId:    travellerId,
      guideId:        conversation.guideId,
      scheduledDate:  new Date(dto.scheduledDate),
      agreedPrice:    dto.agreedPrice,
      notes:          dto.notes,
      status:         TourStatus.PLANNED,
    });
  }

  async getMyTours(travellerId: string, query: GetMyToursQueryDto) {
    const statusFilter = query.status ? [query.status] : ACTIVE_STATUSES;

    const bookings = await this.bookingsRepository.findManyByTraveller(
      travellerId,
      statusFilter,
    );

    return {
      data: bookings,
      total: bookings.length,
    };
  }

  async startTour(bookingId: string, guideId: string) {
    const booking = await this._findAndAuthorizeGuide(bookingId, guideId);

    if (booking.status !== TourStatus.PLANNED) {
      throw new ConflictException('Hanya tur berstatus PLANNED yang bisa dimulai.');
    }

    return this.bookingsRepository.updateStatus(bookingId, {
      status: TourStatus.ONGOING,
      startedAt: new Date(),
    });
  }

  async completeTour(bookingId: string, guideId: string) {
    const booking = await this._findAndAuthorizeGuide(bookingId, guideId);

    if (booking.status !== TourStatus.ONGOING) {
      throw new ConflictException('Hanya tur berstatus ONGOING yang bisa diselesaikan.');
    }

    return this.bookingsRepository.updateStatus(bookingId, {
      status: TourStatus.COMPLETED,
      completedAt: new Date(),
    });
  }

  private async _findAndAuthorizeGuide(bookingId: string, guideId: string) {
    const booking = await this.bookingsRepository.findBookingById(bookingId);
    if (!booking) throw new NotFoundException('Booking tidak ditemukan.');
    if (booking.guideId !== guideId) throw new ForbiddenException('Bukan booking Anda.');
    return booking;
  }
}
