import { Module } from '@nestjs/common';
import axios from 'axios';
import { MoviesController } from './movies.controller';
import { MoviesService } from './movies.service';
import { MOVIES_HTTP } from './movies.types';

@Module({
  controllers: [MoviesController],
  providers: [
    {
      provide: MOVIES_HTTP,
      useFactory: () => axios.create({ timeout: 15_000 }),
    },
    MoviesService,
  ],
})
export class MoviesModule {}
