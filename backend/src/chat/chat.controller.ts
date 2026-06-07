import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ChatService } from './chat.service';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser, RequestUser } from '../auth/decorators/current-user.decorator';

@Controller('conversations')
@UseGuards(JwtAuthGuard)
export class ChatController {
  constructor(private readonly chatService: ChatService) {}

  @Get()
  list(@CurrentUser() user: RequestUser) {
    return this.chatService.listConversations(user.userId);
  }

  @Post()
  findOrCreate(
    @CurrentUser() user: RequestUser,
    @Body() dto: CreateConversationDto,
  ) {
    return this.chatService.findOrCreateConversation(user.userId, dto);
  }

  @Get(':id')
  getOne(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.chatService.getConversation(id, user.userId);
  }

  @Get(':id/messages')
  getMessages(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.chatService.getMessages(id, user.userId);
  }

  @Patch(':id/accept')
  acceptProposal(@Param('id') id: string, @CurrentUser() user: RequestUser) {
    return this.chatService.acceptProposal(id, user.userId);
  }
}
