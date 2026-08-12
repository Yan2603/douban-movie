import { Field, Float, Int, ObjectType } from '@nestjs/graphql';

@ObjectType()
export class FavoriteMovie {
  @Field(() => Int)
  tmdbId: number;

  @Field()
  title: string;

  @Field(() => String, { nullable: true })
  posterPath: string | null;

  @Field(() => Float, { nullable: true })
  voteAverage: number | null;

  @Field(() => String, { nullable: true })
  releaseDate: string | null;
}
