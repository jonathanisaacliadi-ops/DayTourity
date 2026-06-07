import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
  WsException,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { forwardRef, Inject } from '@nestjs/common';
import { ChatService } from './chat.service';

interface AuthSocket extends Socket {
  userId: string;
}

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: 'chat',
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  constructor(
    @Inject(forwardRef(() => ChatService))
    private readonly chatService: ChatService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async handleConnection(client: AuthSocket) {
    try {
      const token = this.extractToken(client);
      const payload = this.jwtService.verify(token, {
        secret: this.configService.getOrThrow('JWT_SECRET'),
      });
      client.userId = payload.sub;
      client.emit('connected', { userId: client.userId });
    } catch {
      client.emit('error', { message: 'Unauthorized' });
      client.disconnect();
    }
  }

  handleDisconnect(client: AuthSocket) {
    console.log(`Client disconnected: ${client.id}`);
  }


  @SubscribeMessage('join_room')
  async handleJoinRoom(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody() data: { conversationId: string },
  ) {
    try {
      await this.chatService.getConversation(data.conversationId, client.userId);
      await client.join(data.conversationId);
      client.emit('room_joined', { conversationId: data.conversationId });
      const count = await this.chatService.markMessagesRead(
        data.conversationId,
        client.userId,
      );
      if (count > 0) {
        this.server.to(data.conversationId).emit('messages_read', {
          conversationId: data.conversationId,
          readBy: client.userId,
        });
      }
    } catch {
      throw new WsException('Cannot join room: access denied or not found');
    }
  }

  @SubscribeMessage('mark_read')
  async handleMarkRead(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody() data: { conversationId: string },
  ) {
    const count = await this.chatService.markMessagesRead(
      data.conversationId,
      client.userId,
    );
    if (count > 0) {
      this.server.to(data.conversationId).emit('messages_read', {
        conversationId: data.conversationId,
        readBy: client.userId,
      });
    }
  }

  @SubscribeMessage('leave_room')
  handleLeaveRoom(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody() data: { conversationId: string },
  ) {
    client.leave(data.conversationId);
  }

  @SubscribeMessage('send_message')
  async handleSendMessage(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody()
    data: {
      conversationId: string;
      content: string;
      type?: 'TEXT' | 'ITINERARY_PROPOSAL';
    },
  ) {
    try {
      await this.chatService.getConversation(data.conversationId, client.userId);

      const message = await this.chatService.saveMessage({
        conversationId: data.conversationId,
        senderId: client.userId,
        content: data.content,
        type: data.type ?? 'TEXT',
      });

      this.server.to(data.conversationId).emit('new_message', message);
      return { success: true };
    } catch {
      throw new WsException('Failed to send message');
    }
  }

  @SubscribeMessage('send_itinerary')
  async handleSendItinerary(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody()
    data: { conversationId: string; proposal: Record<string, unknown> },
  ) {
    try {
      const conv = await this.chatService.getConversationRaw(data.conversationId);
      if (!conv) throw new WsException('Conversation not found');
      if (conv.guideId !== client.userId) {
        throw new WsException('Only the guide can send itinerary proposals');
      }

      const message = await this.chatService.saveMessage({
        conversationId: data.conversationId,
        senderId: client.userId,
        content: JSON.stringify(data.proposal),
        type: 'ITINERARY_PROPOSAL',
      });

      await this.chatService.setBookingStatus(data.conversationId, 'PROPOSED' as any);

      this.server.to(data.conversationId).emit('new_message', message);
      this.server.to(data.conversationId).emit('status_changed', {
        conversationId: data.conversationId,
        status: 'PROPOSED',
      });

      return { success: true };
    } catch (e) {
      throw new WsException(
        e instanceof WsException ? e.message : 'Failed to send itinerary proposal',
      );
    }
  }

  @SubscribeMessage('typing')
  handleTyping(
    @ConnectedSocket() client: AuthSocket,
    @MessageBody() data: { conversationId: string; isTyping: boolean },
  ) {
    client.to(data.conversationId).emit('typing', {
      userId: client.userId,
      isTyping: data.isTyping,
    });
  }

  emitStatusChanged(conversationId: string, status: string) {
    this.server
      .to(conversationId)
      .emit('status_changed', { conversationId, status });
  }


  private extractToken(client: Socket): string {
    const authHeader = client.handshake.headers.authorization as string;
    if (authHeader?.startsWith('Bearer ')) {
      return authHeader.slice(7);
    }
    const queryToken = client.handshake.auth?.token as string;
    if (queryToken) return queryToken;
    throw new Error('No token provided');
  }
}
