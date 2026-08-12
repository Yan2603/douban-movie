import { Test, TestingModule } from '@nestjs/testing';
import { TypeOrmModule } from '@nestjs/typeorm';
import { randomUUID } from 'crypto';
import { Favorite } from './entities/favorite.entity';
import { FavoritesService } from './favorites.service';

describe('FavoritesService', () => {
  let service: FavoritesService;
  let moduleRef: TestingModule;

  const input = {
    tmdbId: 550,
    title: 'Fight Club',
    posterPath: '/p.jpg',
    voteAverage: 8.4,
    releaseDate: '1999-10-15',
  };

  beforeAll(async () => {
    moduleRef = await Test.createTestingModule({
      imports: [
        TypeOrmModule.forRoot({
          type: 'postgres',
          url:
            process.env.DATABASE_URL ??
            'postgres://douban:douban@localhost:5433/douban_movie',
          entities: [Favorite],
          synchronize: true,
        }),
        TypeOrmModule.forFeature([Favorite]),
      ],
      providers: [FavoritesService],
    }).compile();

    service = moduleRef.get(FavoritesService);
  });

  afterAll(async () => {
    await moduleRef?.close();
  });

  it('addFavorite is idempotent', async () => {
    const userId = randomUUID();
    const a = await service.add(userId, input);
    const b = await service.add(userId, input);
    expect(a.tmdbId).toBe(b.tmdbId);
    expect(a.id).toBe(b.id);
    expect(await service.listForUser(userId)).toHaveLength(1);
  });

  it('isolates favorites per user', async () => {
    const userA = randomUUID();
    const userB = randomUUID();
    await service.add(userA, input);
    await service.add(userB, {
      ...input,
      tmdbId: 680,
      title: 'Pulp Fiction',
    });

    const listA = await service.listForUser(userA);
    const listB = await service.listForUser(userB);

    expect(listA).toHaveLength(1);
    expect(listA[0].tmdbId).toBe(550);
    expect(listB).toHaveLength(1);
    expect(listB[0].tmdbId).toBe(680);
  });

  it('removeFavorite deletes only matching user row', async () => {
    const userId = randomUUID();
    const other = randomUUID();
    await service.add(userId, input);
    await service.add(other, input);

    expect(await service.remove(userId, input.tmdbId)).toBe(true);
    expect(await service.listForUser(userId)).toHaveLength(0);
    expect(await service.listForUser(other)).toHaveLength(1);
    expect(await service.remove(userId, input.tmdbId)).toBe(false);
  });
});
