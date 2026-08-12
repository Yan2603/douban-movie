export const MOVIES_HTTP = 'MOVIES_HTTP';

export type MoviesHttpClient = {
  get<T = unknown>(
    url: string,
    config?: {
      params?: Record<string, string | number>;
      timeout?: number;
    },
  ): Promise<{ data: T }>;
};

export type MovieSummary = {
  id: number;
  title: string;
  poster_path: string | null;
  vote_average: number;
  release_date: string | null;
};

export type MovieDetailDto = MovieSummary & {
  backdrop_path: string | null;
  overview: string | null;
};
