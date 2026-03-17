import { relations } from "drizzle-orm/relations";
import { users, commitAnalyses } from "./schema";

export const commitAnalysesRelations = relations(commitAnalyses, ({one}) => ({
	user: one(users, {
		fields: [commitAnalyses.userId],
		references: [users.id]
	}),
}));

export const usersRelations = relations(users, ({many}) => ({
	commitAnalyses: many(commitAnalyses),
}));