import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Inject,
  forwardRef,
} from '@nestjs/common';
import { BookingStatus, Prisma } from '@prisma/client';
import { ChatRepository } from './chat.repository';
import { CreateConversationDto } from './dto/create-conversation.dto';
import { ChatGateway } from './chat.gateway';

@Injectable()
export class ChatService {
  constructor(
    private readonly chatRepository: ChatRepository,
    @Inject(forwardRef(() => ChatGateway))
    private readonly gateway: ChatGateway,
  ) {}

  async findOrCreateConversation(userId: string, dto: CreateConversationDto) {
    const existing = await this.chatRepository.findConversationByParticipants(
      userId,
      dto.guideId,
      dto.tourId,
    );
    if (existing) return this.serializeConversation(existing);

    try {
      const created = await this.chatRepository.createConversation({
        userId,
        guideId: dto.guideId,
        tourId: dto.tourId,
      });
      return this.serializeConversation(created);
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        const conv = await this.chatRepository.findConversationByParticipants(
          userId,
          dto.guideId,
          dto.tourId,
        );
        if (conv) return this.serializeConversation(conv);
      }
      throw e;
    }
  }

  async listConversations(userId: string) {
    const rows = await this.chatRepository.findManyForUser(userId);
    return rows.map(this.serializeConversation);
  }

  async getConversation(id: string, userId: string) {
    const conv = await this.chatRepository.findConversationById(id);
    if (!conv) throw new NotFoundException('Conversation not found');
    if (conv.userId !== userId && conv.guideId !== userId) {
      throw new ForbiddenException('Access denied');
    }
    return this.serializeConversation(conv);
  }

  async getConversationRaw(id: string) {
    return this.chatRepository.findConversationRaw(id);
  }

  async setBookingStatus(conversationId: string, status: BookingStatus) {
    return this.chatRepository.updateBookingStatus(conversationId, status);
  }

  async acceptProposal(conversationId: string, userId: string) {
    const conv = await this.chatRepository.findConversationRaw(conversationId);
    if (!conv) throw new NotFoundException('Conversation not found');
    if (conv.userId !== userId) {
      throw new ForbiddenException('Only the user can accept proposals');
    }
    if (conv.bookingStatus !== BookingStatus.PROPOSED) {
      throw new BadRequestException('No active proposal to accept');
    }

    const updated = await this.setBookingStatus(
      conversationId,
      BookingStatus.ACCEPTED,
    );

    this.gateway.emitStatusChanged(conversationId, 'ACCEPTED');

    return updated;
  }

  async getMessages(conversationId: string, userId: string) {
    await this.getConversation(conversationId, userId);
    return this.chatRepository.findMessages(conversationId);
  }

  markMessagesRead(
    conversationId: string,
    readerId: string,
  ): Promise<number> {
    return this.chatRepository.markMessagesRead(conversationId, readerId);
  }

  async saveMessage(data: {
    conversationId: string;
    senderId: string;
    content: string;
    type?: 'TEXT' | 'ITINERARY_PROPOSAL';
  }) {
    await this.chatRepository.touchConversation(data.conversationId);

    return this.chatRepository.createMessage({
      conversationId: data.conversationId,
      senderId: data.senderId,
      content: data.content,
      type: data.type ?? 'TEXT',
    });
  }

  private serializeConversation(conv: any) {
    return {
      id: conv.id,
      bookingStatus: conv.bookingStatus,
      user: conv.user,
      guide: conv.guide,
      tour: conv.tour,
      lastMessage: conv.messages?.[0] ?? null,
      createdAt: conv.createdAt,
      updatedAt: conv.updatedAt,
    };
  }
}
