import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { Request } from 'express';
import { JwtRequestUser } from '../guards/jwt-auth.guard';

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtRequestUser => {
    const request = ctx
      .switchToHttp()
      .getRequest<Request & { user: JwtRequestUser }>();
    return request.user;
  },
);
