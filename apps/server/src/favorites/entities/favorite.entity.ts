import {
  Column,
  CreateDateColumn,
  Entity,
  PrimaryGeneratedColumn,
  Unique,
} from 'typeorm';

@Entity('favorites')
@Unique(['userId', 'tmdbId'])
export class Favorite {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @Column({ name: 'tmdb_id', type: 'int' })
  tmdbId: number;

  @Column()
  title: string;

  @Column({ name: 'poster_path', type: 'varchar', nullable: true })
  posterPath: string | null;

  @Column({ name: 'vote_average', type: 'float', default: 0 })
  voteAverage: number;

  @Column({ name: 'release_date', type: 'varchar', nullable: true })
  releaseDate: string | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
