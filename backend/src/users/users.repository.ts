import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PricePreference, Role, User } from '@prisma/client';

type UserSummary = Pick<
  User,
  'id' | 'email' | 'name' | 'role' | 'pricePreference'
>;

const userSummarySelect = {
  id: true,
  email: true,
  name: true,
  role: true,
  pricePreference: true,
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
}
