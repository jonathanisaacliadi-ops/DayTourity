import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { Currency, PricePreference, Role, User } from '@prisma/client';

type UserSummary = Pick<
  User,
  'id' | 'email' | 'name' | 'role' | 'pricePreference' | 'currency'
>;

const userSummarySelect = {
  id: true,
  email: true,
  name: true,
  role: true,
  pricePreference: true,
  currency: true,
} as const;


@Injectable()
export class UsersRepository {
  constructor(private readonly prisma: PrismaService) {}

  findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  create(data: {
    email: string;
    name: string;
    password: string;
  }): Promise<User> {
    return this.prisma.user.create({ data });
  }

  updatePreferences(
    userId: string,
    pricePreference: PricePreference,
  ): Promise<UserSummary> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { pricePreference },
      select: userSummarySelect,
    });
  }

  updateCurrency(userId: string, currency: Currency): Promise<UserSummary> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { currency },
      select: userSummarySelect,
    });
  }

  findRoleById(userId: string): Promise<Pick<User, 'role'>> {
    return this.prisma.user.findUniqueOrThrow({
      where: { id: userId },
      select: { role: true },
    });
  }

  updateRole(userId: string, role: Role): Promise<UserSummary> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { role },
      select: userSummarySelect,
    });
  }

  applyForGuide(userId: string, phone: string): Promise<UserSummary> {
    return this.prisma.user.update({
      where: { id: userId },
      data: { role: Role.PENDING_GUIDE, phone },
      select: userSummarySelect,
    });
  }

  findPendingGuides(): Promise<
    Pick<User, 'id' | 'name' | 'email' | 'phone' | 'createdAt'>[]
  > {
    return this.prisma.user.findMany({
      where: { role: Role.PENDING_GUIDE },
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }
}
