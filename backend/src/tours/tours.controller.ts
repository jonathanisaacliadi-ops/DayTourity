import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ToursService } from './tours.service';
import { GetToursQueryDto } from './dto/get-tours-query.dto';
import { CreateTourDto } from './dto/create-tour.dto';
import { UpdateTourDto } from './dto/update-tour.dto';
import { AddPhotoDto } from './dto/add-photo.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import {
  CurrentUser,
  RequestUser,
} from '../auth/decorators/current-user.decorator';

@Controller('tours')
@UseGuards(JwtAuthGuard)
export class ToursController {
  constructor(private readonly toursService: ToursService) {}

  @Get()
  getRecommended(@Query() query: GetToursQueryDto) {
    return this.toursService.getRecommended(query);
  }

  @Get(':id')
  findById(@Param('id') id: string) {
    return this.toursService.findById(id);
  }

  @Post()
  @UseGuards(RolesGuard)
  @Roles('GUIDE')
  create(@CurrentUser() user: RequestUser, @Body() dto: CreateTourDto) {
    return this.toursService.create(user.userId, dto);
  }

  @Patch(':id')
  @UseGuards(RolesGuard)
  @Roles('GUIDE')
  update(
    @Param('id') id: string,
    @CurrentUser() user: RequestUser,
    @Body() dto: UpdateTourDto,
  ) {
    return this.toursService.updateTour(id, user.userId, dto);
  }

  @Delete(':id')
  @UseGuards(RolesGuard)
  @Roles('GUIDE')
  deleteTour(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.toursService.deleteTour(id, user.userId);
  }

  @Post(':id/photos')
  @UseGuards(RolesGuard)
  @Roles('GUIDE')
  addPhoto(
    @Param('id') tourId: string,
    @CurrentUser() user: RequestUser,
    @Body() dto: AddPhotoDto,
  ) {
    return this.toursService.addPhoto(tourId, user.userId, dto.url);
  }

  @Delete(':id/photos/:photoId')
  @UseGuards(RolesGuard)
  @Roles('GUIDE')
  removePhoto(
    @Param('id') tourId: string,
    @Param('photoId') photoId: string,
    @CurrentUser() user: RequestUser,
  ) {
    return this.toursService.removePhoto(tourId, photoId, user.userId);
  }
}
