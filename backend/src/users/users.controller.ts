import { Body, Controller, Get, Patch, Post, UseGuards } from '@nestjs/common';
import { UsersService } from './users.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import {
  CurrentUser,
  RequestUser,
} from '../auth/decorators/current-user.decorator';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import { BecomeGuideDto } from './dto/become-guide.dto';
 
@Controller('users')
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}
 
  @Get('me')
  getMe(@CurrentUser() user: RequestUser) {
    return this.usersService.findById(user.userId);
  }
 
  @Patch('me/preferences')
  updatePreferences(
    @CurrentUser() user: RequestUser,
    @Body() dto: UpdatePreferencesDto,
  ) {
    return this.usersService.updatePreferences(user.userId, dto.pricePreference);
  }
  @Patch('me/become-guide')
  becomeGuide(@CurrentUser() user: RequestUser) {
    return this.usersService.becomeGuide(user.userId);
  }
}