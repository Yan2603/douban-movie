import {
  BadGatewayException,
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import {
  MOVIES_HTTP,
  MovieDetailDto,
  MovieSummary,
  MoviesHttpClient,
} from './movies.types';

const TMDB_BASE = 'https://api.themoviedb.org/3';
const REQUEST_TIMEOUT_MS = 15_000;

@Injectable()
export class MoviesService {
  constructor(
    @Inject(MOVIES_HTTP) private readonly http: MoviesHttpClient,
    private readonly config: ConfigService,
  ) {}

  async nowPlaying(page: number): Promise<MovieSummary[]> {
    const data = await this.request<{ results: Record<string, unknown>[] }>(
      `${TMDB_BASE}/movie/now_playing`,
      {
        language: 'zh-CN',
        region: 'CN',
        page,
      },
    );
    return (data.results ?? []).map((item) => this.mapSummary(item));
  }

  async detail(tmdbId: number): Promise<MovieDetailDto> {
    const data = await this.request<Record<string, unknown>>(
      `${TMDB_BASE}/movie/${tmdbId}`,
      { language: 'zh-CN' },
    );
    return this.mapDetail(data);
  }

  private apiKey(): string {
    const key = this.config.get<string>('TMDB_API_KEY')?.trim();
    if (!key) {
      throw new ServiceUnavailableException(
        'TMDB_API_KEY is not configured on the server',
      );
    }
    return key;
  }

  private async request<T>(
    url: string,
    params: Record<string, string | number>,
  ): Promise<T> {
    try {
      const { data } = await this.http.get<T>(url, {
        params: { api_key: this.apiKey(), ...params },
        timeout: REQUEST_TIMEOUT_MS,
      });
      return data;
    } catch (err) {
      this.rethrowUpstream(err);
    }
  }

  private rethrowUpstream(err: unknown): never {
    if (err instanceof NotFoundException || err instanceof BadGatewayException) {
      throw err;
    }
    if (err instanceof ServiceUnavailableException) {
      throw err;
    }

    const status = axios.isAxiosError(err)
      ? err.response?.status
      : (err as { response?: { status?: number } })?.response?.status;
    const code = axios.isAxiosError(err)
      ? err.code
      : (err as { code?: string })?.code;

    if (status === 404) {
      throw new NotFoundException('Movie not found');
    }
    if (
      code === 'ECONNABORTED' ||
      code === 'ETIMEDOUT' ||
      status === undefined ||
      status >= 500
    ) {
      throw new BadGatewayException('TMDB upstream unavailable');
    }
    throw new BadGatewayException('TMDB upstream request failed');
  }

  private mapSummary(item: Record<string, unknown>): MovieSummary {
    return {
      id: Number(item.id),
      title: String(item.title ?? ''),
      poster_path: (item.poster_path as string | null) ?? null,
      vote_average: Number(item.vote_average ?? 0),
      release_date: (item.release_date as string | null) ?? null,
    };
  }

  private mapDetail(item: Record<string, unknown>): MovieDetailDto {
    return {
      ...this.mapSummary(item),
      backdrop_path: (item.backdrop_path as string | null) ?? null,
      overview: (item.overview as string | null) ?? null,
    };
  }
}
