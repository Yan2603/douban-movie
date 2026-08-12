import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';

export type JwtRequestUser = { userId: string };

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
  ) {}

  getRequest(context: ExecutionContext): Request {
    return context.switchToHttp().getRequest<Request>();
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = this.getRequest(context);
    const token = extractBearer(request.headers.authorization);
    if (!token) {
      throw new UnauthorizedException();
    }

    const secret = this.config.get<string>('JWT_ACCESS_SECRET');
    if (!secret) {
      throw new Error('Missing config: JWT_ACCESS_SECRET');
    }

    try {
      const payload = await this.jwtService.verifyAsync<{ sub: string }>(
        token,
        { secret },
      );
      if (!payload?.sub) {
        throw new UnauthorizedException();
      }
      (request as Request & { user: JwtRequestUser }).user = {
        userId: payload.sub,
      };
      return true;
    } catch (err) {
      if (err instanceof UnauthorizedException) {
        throw err;
      }
      throw new UnauthorizedException();
    }
  }
}

function extractBearer(authorization?: string): string | null {
  if (!authorization) {
    return null;
  }
  const [scheme, token] = authorization.split(' ');
  if (scheme?.toLowerCase() !== 'bearer' || !token) {
    return null;
  }
  return token;
}
