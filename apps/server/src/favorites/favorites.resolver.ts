import { UseGuards } from '@nestjs/common';
import { Args, Int, Mutation, Query, Resolver } from '@nestjs/graphql';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { GqlJwtAuthGuard } from '../auth/guards/gql-jwt-auth.guard';
import { JwtRequestUser } from '../auth/guards/jwt-auth.guard';
import { AddFavoriteInput } from './dto/add-favorite.input';
import { FavoriteMovie } from './models/favorite-movie.model';
import { FavoritesService } from './favorites.service';

@Resolver(() => FavoriteMovie)
export class FavoritesResolver {
  constructor(private readonly favorites: FavoritesService) {}

  @Query(() => [FavoriteMovie])
  @UseGuards(GqlJwtAuthGuard)
  myFavorites(@CurrentUser() user: JwtRequestUser) {
    return this.favorites.listForUser(user.userId);
  }

  @Mutation(() => FavoriteMovie)
  @UseGuards(GqlJwtAuthGuard)
  addFavorite(
    @CurrentUser() user: JwtRequestUser,
    @Args('input') input: AddFavoriteInput,
  ) {
    return this.favorites.add(user.userId, input);
  }

  @Mutation(() => Boolean)
  @UseGuards(GqlJwtAuthGuard)
  removeFavorite(
    @CurrentUser() user: JwtRequestUser,
    @Args('tmdbId', { type: () => Int }) tmdbId: number,
  ) {
    return this.favorites.remove(user.userId, tmdbId);
  }
}
