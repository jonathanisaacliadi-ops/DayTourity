import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ToursModule } from './tours/tours.module';
import { BookingsModule } from './bookings/bookings.module';
import { ChatModule } from './chat/chat.module';
import { UploadsModule } from './uploads/uploads.module';
import { HealthModule } from './health/health.module';
import { ExchangeRatesModule } from './exchange-rates/exchange-rates.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
    AuthModule,
    ToursModule,
    BookingsModule,
    ChatModule,
    UploadsModule,
    HealthModule,
    ExchangeRatesModule,
  ],
})

export class AppModule {}