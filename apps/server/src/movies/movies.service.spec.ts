import {
  BadGatewayException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MoviesService } from './movies.service';

describe('MoviesService', () => {
  const configWithKey = {
    get: (key: string) => (key === 'TMDB_API_KEY' ? 'test-key' : undefined),
  } as ConfigService;

  const configWithoutKey = {
    get: () => undefined,
  } as unknown as ConfigService;

  it('maps now_playing results', async () => {
    const http = {
      get: jest.fn().mockResolvedValue({
        data: {
          results: [
            {
              id: 1,
              title: 'A',
              poster_path: '/x.jpg',
              vote_average: 8.1,
              release_date: '2024-01-01',
            },
          ],
        },
      }),
    };
    const service = new MoviesService(http as any, configWithKey);
    const list = await service.nowPlaying(1);
    expect(list[0]).toEqual({
      id: 1,
      title: 'A',
      poster_path: '/x.jpg',
      vote_average: 8.1,
      release_date: '2024-01-01',
    });
    expect(http.get).toHaveBeenCalledWith(
      'https://api.themoviedb.org/3/movie/now_playing',
      expect.objectContaining({
        params: expect.objectContaining({
          api_key: 'test-key',
          language: 'zh-CN',
          region: 'CN',
          page: 1,
        }),
      }),
    );
  });

  it('maps movie detail fields', async () => {
    const http = {
      get: jest.fn().mockResolvedValue({
        data: {
          id: 550,
          title: 'Fight Club',
          poster_path: '/p.jpg',
          backdrop_path: '/b.jpg',
          vote_average: 8.4,
          release_date: '1999-10-15',
          overview: 'An insomniac...',
          extra_noise: true,
        },
      }),
    };
    const service = new MoviesService(http as any, configWithKey);
    const detail = await service.detail(550);
    expect(detail).toEqual({
      id: 550,
      title: 'Fight Club',
      poster_path: '/p.jpg',
      backdrop_path: '/b.jpg',
      vote_average: 8.4,
      release_date: '1999-10-15',
      overview: 'An insomniac...',
    });
    expect(http.get).toHaveBeenCalledWith(
      'https://api.themoviedb.org/3/movie/550',
      expect.objectContaining({
        params: expect.objectContaining({
          api_key: 'test-key',
          language: 'zh-CN',
        }),
      }),
    );
  });

  it('throws NotFoundException on upstream 404', async () => {
    const http = {
      get: jest.fn().mockRejectedValue({
        response: { status: 404 },
        isAxiosError: true,
      }),
    };
    const service = new MoviesService(http as any, configWithKey);
    await expect(service.detail(999)).rejects.toBeInstanceOf(NotFoundException);
  });

  it('throws BadGatewayException on upstream 5xx', async () => {
    const http = {
      get: jest.fn().mockRejectedValue({
        response: { status: 503 },
        isAxiosError: true,
      }),
    };
    const service = new MoviesService(http as any, configWithKey);
    await expect(service.nowPlaying(1)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it('throws BadGatewayException on timeout', async () => {
    const http = {
      get: jest.fn().mockRejectedValue({
        code: 'ECONNABORTED',
        message: 'timeout',
        isAxiosError: true,
      }),
    };
    const service = new MoviesService(http as any, configWithKey);
    await expect(service.nowPlaying(1)).rejects.toBeInstanceOf(
      BadGatewayException,
    );
  });

  it('throws when TMDB_API_KEY is missing', async () => {
    const http = { get: jest.fn() };
    const service = new MoviesService(http as any, configWithoutKey);
    await expect(service.nowPlaying(1)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
    expect(http.get).not.toHaveBeenCalled();
  });
});
