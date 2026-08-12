import { Controller, Get, Param, ParseIntPipe, Query } from '@nestjs/common';
import { MoviesService } from './movies.service';

@Controller('movies')
export class MoviesController {
  constructor(private readonly movies: MoviesService) {}

  @Get('now-playing')
  nowPlaying(@Query('page') page = '1') {
    return this.movies.nowPlaying(Number(page) || 1);
  }

  @Get(':tmdbId')
  detail(@Param('tmdbId', ParseIntPipe) tmdbId: number) {
    return this.movies.detail(tmdbId);
  }
}
