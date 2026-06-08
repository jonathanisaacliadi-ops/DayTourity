import { Injectable, ConflictException } from '@nestjs/common';
import { Currency, PricePreference, Role, User } from '@prisma/client';
import { UsersRepository } from './users.repository';
import { BecomeGuideDto } from './dto/become-guide.dto';

@Injectable()
export class UsersService {
  constructor(private readonly usersRepository: UsersRepository) {}

  findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findByEmail(email);
  }

  findById(id: string): Promise<User | null> {
    return this.usersRepository.findById(id);
  }

  create(data: {
    email: string;
    name: string;
    password: string;
  }): Promise<User> {
    return this.usersRepository.create(data);
  }

  updatePreferences(
    userId: string,
    pricePreference: PricePreference,
  ): Promise<Pick<User, 'id' | 'email' | 'name' | 'role' | 'pricePreference' | 'currency'>> {
    return this.usersRepository.updatePreferences(userId, pricePreference);
  }

  updateCurrency(
    userId: string,
    currency: Currency,
  ): Promise<Pick<User, 'id' | 'email' | 'name' | 'role' | 'pricePreference' | 'currency'>> {
    return this.usersRepository.updateCurrency(userId, currency);
  }

  async becomeGuide(
    userId: string,
    dto: BecomeGuideDto,
  ): Promise<Pick<User, 'id' | 'email' | 'name' | 'role' | 'pricePreference' | 'currency'>> {
    const user = await this.usersRepository.findRoleById(userId);

    if (user.role === Role.PENDING_GUIDE) {
      throw new ConflictException('Your application is already under review.');
    }
    if (user.role === Role.GUIDE) {
      throw new ConflictException('You are already a verified guide.');
    }

    return this.usersRepository.applyForGuide(userId, dto.phone);
  }

  findPendingGuides(): Promise<
    Pick<User, 'id' | 'name' | 'email' | 'phone' | 'createdAt'>[]
  > {
    return this.usersRepository.findPendingGuides();
  }

  async approveGuide(
    userId: string,
  ): Promise<Pick<User, 'id' | 'email' | 'name' | 'role' | 'pricePreference' | 'currency'>> {
    const user = await this.usersRepository.findRoleById(userId);

    if (user.role !== Role.PENDING_GUIDE) {
      throw new ConflictException('This user has no pending application.');
    }

    return this.usersRepository.updateRole(userId, Role.GUIDE);
  }

  async rejectGuide(
    userId: string,
  ): Promise<Pick<User, 'id' | 'email' | 'name' | 'role' | 'pricePreference' | 'currency'>> {
    const user = await this.usersRepository.findRoleById(userId);

    if (user.role !== Role.PENDING_GUIDE) {
      throw new ConflictException('This user has no pending application.');
    }

    return this.usersRepository.updateRole(userId, Role.USER);
  }
}
