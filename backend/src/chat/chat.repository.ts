import { Injectable } from '@nestjs/common';
import { BookingStatus, MessageType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const senderSelect = { sender: { select: { id: true, name: true } } };


@Injectable()
export class ChatRepository {
  constructor(private readonly prisma: PrismaService) {}

  findConversationByParticipants(
    userId: string,
    guideId: string,
    tourId: string,
  ) {
    return this.prisma.conversation.findUnique({
      where: { userId_guideId_tourId: { userId, guideId, tourId } },
      include: this.conversationInclude(),
    });
  }

  createConversation(data: {
    userId: string;
    guideId: string;
    tourId: string;
  }) {
    return this.prisma.conversation.create({
      data,
      include: this.conversationInclude(),
    });
  }

  findManyForUser(userId: string) {
    return this.prisma.conversation.findMany({
      where: { OR: [{ userId }, { guideId: userId }] },
      include: this.conversationInclude(),
      orderBy: { updatedAt: 'desc' },
    });
  }

  findConversationById(id: string) {
    return this.prisma.conversation.findUnique({
      where: { id },
      include: this.conversationInclude(),
    });
  }

  findConversationRaw(id: string) {
    return this.prisma.conversation.findUnique({ where: { id } });
  }

  updateBookingStatus(conversationId: string, status: BookingStatus) {
    return this.prisma.conversation.update({
      where: { id: conversationId },
      data: { bookingStatus: status },
    });
  }

  touchConversation(conversationId: string) {
    return this.prisma.conversation.update({
      where: { id: conversationId },
      data: { updatedAt: new Date() },
    });
  }

  findMessages(conversationId: string) {
    return this.prisma.message.findMany({
      where: { conversationId },
      include: senderSelect,
      orderBy: { createdAt: 'asc' },
    });
  }

  async markMessagesRead(
    conversationId: string,
    readerId: string,
  ): Promise<number> {
    const result = await this.prisma.message.updateMany({
      where: {
        conversationId,
        senderId: { not: readerId },
        isRead: false,
      },
      data: { isRead: true },
    });
    return result.count;
  }

  createMessage(data: {
    conversationId: string;
    senderId: string;
    content: string;
    type: MessageType;
  }) {
    return this.prisma.message.create({
      data,
      include: senderSelect,
    });
  }

  private conversationInclude() {
    return {
      user: { select: { id: true, name: true } },
      guide: { select: { id: true, name: true } },
      tour: { select: { id: true, title: true, coverImageUrl: true } },
      messages: {
        orderBy: { createdAt: 'desc' as const },
        take: 1,
        include: senderSelect,
      },
    };
  }
}
