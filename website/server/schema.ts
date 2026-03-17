import { pgTable, serial, varchar, integer, boolean, timestamp, real } from 'drizzle-orm/pg-core';

// Tabla de usuarios
export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  username: varchar('username', { length: 50 }).notNull(),
  email: varchar('email', { length: 100 }).notNull(),
  password: varchar('password', { length: 255 }).notNull(),
  created_at: timestamp('created_at').defaultNow(),
});

// Tabla de análisis de commits
export const commit_analyses = pgTable('commit_analyses', {
  id: serial('id').primaryKey(),
  commit_hash: varchar('commit_hash', { length: 40 }).notNull(),
  user_id: integer('user_id').references(() => users.id, { onDelete: 'cascade' }),
  risk_score: real('risk_score').default(0), // Validación de 0-100 se hace en lógica
  lines_added: integer('lines_added').default(0),
  lines_deleted: integer('lines_deleted').default(0),
  files_modified: integer('files_modified').default(0),
  tests_modified: boolean('tests_modified').default(false),
  complex_sql_added: boolean('complex_sql_added').default(false),
  analysis_date: timestamp('analysis_date').defaultNow(),
  risk_label: varchar('risk_label', { length: 50 })
});