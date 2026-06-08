import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import {
  CurrentUser,
  RequestUser,
} from '../auth/decorators/current-user.decorator';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import { UpdateCurrencyDto } from './dto/update-currency.dto';
import { BecomeGuideDto } from './dto/become-guide.dto';

@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  getMe(@CurrentUser() user: RequestUser) {
    return this.usersService.findById(user.userId);
  }

  @Get('pending-guides')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  getPendingGuides() {
    return this.usersService.findPendingGuides();
  }

  @Patch('me/preferences')
  updatePreferences(
    @CurrentUser() user: RequestUser,
    @Body() dto: UpdatePreferencesDto,
  ) {
    return this.usersService.updatePreferences(user.userId, dto.pricePreference);
  }

  @Patch('me/currency')
  updateCurrency(
    @CurrentUser() user: RequestUser,
    @Body() dto: UpdateCurrencyDto,
  ) {
    return this.usersService.updateCurrency(user.userId, dto.currency);
  }

  @Patch('me/become-guide')
  becomeGuide(@CurrentUser() user: RequestUser, @Body() dto: BecomeGuideDto) {
    return this.usersService.becomeGuide(user.userId, dto);
  }

  @Patch(':id/approve-guide')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  approveGuide(@Param('id') id: string) {
    return this.usersService.approveGuide(id);
  }

  @Patch(':id/reject-guide')
  @UseGuards(RolesGuard)
  @Roles('ADMIN')
  rejectGuide(@Param('id') id: string) {
    return this.usersService.rejectGuide(id);
  }
}
