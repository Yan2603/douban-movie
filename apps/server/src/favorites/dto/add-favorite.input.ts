import { Field, Float, InputType, Int } from '@nestjs/graphql';
import {
  IsNumber,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';

@InputType()
export class AddFavoriteInput {
  @Field(() => Int)
  @IsNumber()
  tmdbId: number;

  @Field()
  @IsString()
  @MinLength(1)
  title: string;

  @Field(() => String, { nullable: true })
  @IsOptional()
  @IsString()
  posterPath?: string | null;

  @Field(() => Float, { nullable: true })
  @IsOptional()
  @IsNumber()
  voteAverage?: number | null;

  @Field(() => String, { nullable: true })
  @IsOptional()
  @IsString()
  releaseDate?: string | null;
}
