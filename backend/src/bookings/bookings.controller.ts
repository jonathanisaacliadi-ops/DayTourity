import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { BookingsService } from './bookings.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { CurrentUser, RequestUser } from '../auth/decorators/current-user.decorator';
import { CreateBookingDto } from './dto/create-booking.dto';
import { ReserveBookingDto } from './dto/reserve-booking.dto';
import { GetMyToursQueryDto } from './dto/get-my-tours-query.dto';

@Controller('bookings')
@UseGuards(JwtAuthGuard)
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  @Post()
  create(
    @CurrentUser() user: RequestUser,
    @Body() dto: CreateBookingDto,
  ) {
    return this.bookingsService.createBooking(user.userId, dto);
  }

  @Post('reserve')
  reserve(
    @CurrentUser() user: RequestUser,
    @Body() dto: ReserveBookingDto,
  ) {
    return this.bookingsService.reserve(user.userId, dto);
  }

  @Get('my-tours')
  getMyTours(
    @CurrentUser() user: RequestUser,
    @Query() query: GetMyToursQueryDto,
  ) {
    return this.bookingsService.getMyTours(user.userId, query);
  }

  @Get('guide')
  getGuideBookings(@CurrentUser() user: RequestUser) {
    return this.bookingsService.getGuideBookings(user.userId);
  }

  @Patch(':id/cancel')
  cancel(
    @Param('id') id: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.bookingsService.cancelBooking(id, user.userId);
  }

  @Patch(':id/start')
  @UseGuards(RolesGuard)
  @Roles('GUIDE')
  startTour(
    @Param('id') id: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.bookingsService.startTour(id, user.userId);
  }
 
  @Patch(':id/complete')
  @UseGuards(RolesGuard)
  @Roles('GUIDE')
  completeTour(
    @Param('id') id: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.bookingsService.completeTour(id, user.userId);
  }
}