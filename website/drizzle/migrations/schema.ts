import { pgTable, serial, varchar, timestamp, foreignKey, integer, boolean } from "drizzle-orm/pg-core"
import { sql } from "drizzle-orm"



export const users = pgTable("users", {
	id: serial().primaryKey().notNull(),
	username: varchar({ length: 50 }).notNull(),
	email: varchar({ length: 100 }).notNull(),
	password: varchar({ length: 255 }).notNull(),
	createdAt: timestamp("created_at", { mode: 'string' }).defaultNow(),
});

export const commitAnalyses = pgTable("commit_analyses", {
	id: serial().primaryKey().notNull(),
	commitHash: varchar("commit_hash", { length: 40 }).notNull(),
	userId: integer("user_id"),
	riskScore: integer("risk_score").default(0),
	linesAdded: integer("lines_added").default(0),
	linesDeleted: integer("lines_deleted").default(0),
	filesModified: integer("files_modified").default(0),
	testsModified: boolean("tests_modified").default(false),
	complexSqlAdded: boolean("complex_sql_added").default(false),
	analysisDate: timestamp("analysis_date", { mode: 'string' }).defaultNow(),
	riskLabel: varchar("risk_label", { length: 50 }),
}, (table) => [
	foreignKey({
			columns: [table.userId],
			foreignColumns: [users.id],
			name: "commit_analyses_user_id_users_id_fk"
		}).onDelete("cascade"),
]);
