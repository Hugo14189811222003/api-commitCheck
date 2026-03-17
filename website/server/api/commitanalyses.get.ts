import { db } from '../db';
import { commit_analyses } from '../schema';

export default defineEventHandler(async (event) => {
    try {
        const result = await db.select().from(commit_analyses);
        return { commit_analises: result }
    } catch (error) {
        console.error("hubo un problema al obtener los commit analizados, error: ", error);
        return { error: 'No se pudieron obtener los usuarios' }
    }
})