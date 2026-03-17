import { db } from '../../db';
import { commit_analyses } from '../../schema';
import { eq } from 'drizzle-orm';

export default defineEventHandler(async (event) => {
  // ── 1. ID del param ──────────────────────────────────────────────────────
  const id = Number(getRouterParam(event, 'id'))
  if (!Number.isInteger(id) || id <= 0) {
    throw createError({ statusCode: 400, message: 'El id debe ser un entero positivo' })
  }

  // ── 2. Verificar que existe ───────────────────────────────────────────────
  const existing = await db
    .select({ id: commit_analyses.id, commit_hash: commit_analyses.commit_hash })
    .from(commit_analyses)
    .where(eq(commit_analyses.id, id))
    .limit(1)

  if (existing.length === 0) {
    throw createError({ statusCode: 404, message: `No existe un análisis con id ${id}` })
  }

  // ── 3. Eliminar ───────────────────────────────────────────────────────────
  try {
    await db.delete(commit_analyses).where(eq(commit_analyses.id, id))

    return {
      message: `Análisis del commit ${existing[0]!.commit_hash} eliminado correctamente`
    }

  } catch (error) {
    console.error('[commit-analyses.delete] Error inesperado:', error)
    throw createError({ statusCode: 500, message: 'No se pudo eliminar el análisis' })
  }
})