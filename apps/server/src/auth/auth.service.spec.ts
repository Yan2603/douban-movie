import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuthService } from './auth.service';
import { RefreshToken } from './entities/refresh-token.entity';
import { User } from './entities/user.entity';

describe('AuthService', () => {
  let service: AuthService;
  let moduleRef: TestingModule;

  beforeAll(async () => {
    moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          envFilePath: ['.env', '../../.env'],
        }),
        JwtModule.register({}),
        TypeOrmModule.forRoot({
          type: 'postgres',
          url:
            process.env.DATABASE_URL ??
            'postgres://douban:douban@localhost:5433/douban_movie',
          entities: [User, RefreshToken],
          synchronize: true,
        }),
        TypeOrmModule.forFeature([User, RefreshToken]),
      ],
      providers: [AuthService],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  afterAll(async () => {
    await moduleRef?.close();
  });

  it('register returns token pair', async () => {
    const username = `alice_${Date.now()}`;
    const result = await service.register({ username, password: 'secret1' });
    expect(result.accessToken).toBeDefined();
    expect(result.refreshToken).toBeDefined();
  });

  it('duplicate username throws ConflictException', async () => {
    const username = `dup_${Date.now()}`;
    await service.register({ username, password: 'secret1' });
    await expect(
      service.register({ username, password: 'secret1' }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('login returns token pair for valid credentials', async () => {
    const username = `bob_${Date.now()}`;
    await service.register({ username, password: 'secret1' });
    const result = await service.login({ username, password: 'secret1' });
    expect(result.accessToken).toBeDefined();
    expect(result.refreshToken).toBeDefined();
  });

  it('login throws UnauthorizedException for bad password', async () => {
    const username = `carol_${Date.now()}`;
    await service.register({ username, password: 'secret1' });
    await expect(
      service.login({ username, password: 'wrongpass' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('refresh rotates token and rejects old refresh', async () => {
    const first = await service.register({
      username: `bob_${Date.now()}`,
      password: 'secret1',
    });
    const second = await service.refresh(first.refreshToken);
    await expect(service.refresh(first.refreshToken)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(second.accessToken).toBeDefined();
  });

  it('logout revokes refresh', async () => {
    const tokens = await service.register({
      username: `carol_logout_${Date.now()}`,
      password: 'secret1',
    });
    await service.logout(tokens.refreshToken);
    await expect(service.refresh(tokens.refreshToken)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
  });
});
