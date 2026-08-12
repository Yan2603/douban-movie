import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { QueryFailedError, Repository } from 'typeorm';
import { AddFavoriteInput } from './dto/add-favorite.input';
import { Favorite } from './entities/favorite.entity';

@Injectable()
export class FavoritesService {
  constructor(
    @InjectRepository(Favorite)
    private readonly favorites: Repository<Favorite>,
  ) {}

  listForUser(userId: string): Promise<Favorite[]> {
    return this.favorites.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });
  }

  async add(userId: string, input: AddFavoriteInput): Promise<Favorite> {
    const existing = await this.favorites.findOne({
      where: { userId, tmdbId: input.tmdbId },
    });
    if (existing) {
      return existing;
    }

    const favorite = this.favorites.create({
      userId,
      tmdbId: input.tmdbId,
      title: input.title,
      posterPath: input.posterPath ?? null,
      voteAverage: input.voteAverage ?? 0,
      releaseDate: input.releaseDate ?? null,
    });

    try {
      return await this.favorites.save(favorite);
    } catch (err) {
      if (isUniqueViolation(err)) {
        const raced = await this.favorites.findOne({
          where: { userId, tmdbId: input.tmdbId },
        });
        if (raced) {
          return raced;
        }
      }
      throw err;
    }
  }

  async remove(userId: string, tmdbId: number): Promise<boolean> {
    const result = await this.favorites.delete({ userId, tmdbId });
    return (result.affected ?? 0) > 0;
  }
}

function isUniqueViolation(err: unknown): boolean {
  return (
    err instanceof QueryFailedError &&
    typeof (err as QueryFailedError & { code?: string }).code === 'string' &&
    (err as QueryFailedError & { code?: string }).code === '23505'
  );
}
