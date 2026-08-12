import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { GqlContextType, GqlExecutionContext } from '@nestjs/graphql';
import { Request } from 'express';
import { JwtRequestUser } from '../guards/jwt-auth.guard';

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtRequestUser => {
    if (ctx.getType<GqlContextType>() === 'graphql') {
      const gqlCtx = GqlExecutionContext.create(ctx);
      return gqlCtx.getContext<{ req: Request & { user: JwtRequestUser } }>()
        .req.user;
    }
    const request = ctx
      .switchToHttp()
      .getRequest<Request & { user: JwtRequestUser }>();
    return request.user;
  },
);
