import { db } from '../db';
import { commit_analyses } from '../schema';
import { eq } from 'drizzle-orm';

export default defineEventHandler(async (event) => {
  const body = await readBody(event)

  // ── 1. Campos requeridos ─────────────────────────────────────────────────
  const missingFields: string[] = []
  if (!body.commit_hash) missingFields.push('commit_hash')
  if (body.user_id === undefined || body.user_id === null) missingFields.push('user_id')

  if (missingFields.length > 0) {
    throw createError({
      statusCode: 400,
      message: `Campos requeridos faltantes: ${missingFields.join(', ')}`
    })
  }

  // ── 2. Tipos ─────────────────────────────────────────────────────────────
  if (typeof body.commit_hash !== 'string') {
    throw createError({ statusCode: 400, message: 'commit_hash debe ser un string' })
  }

  const userId = Number(body.user_id)
  if (isNaN(userId) || !Number.isInteger(userId) || userId <= 0) {
    throw createError({ statusCode: 400, message: 'user_id debe ser un número entero positivo' })
  }

  // ── 3. Formato commit_hash (40 chars hexadecimales) ──────────────────────
  const commit_hash = body.commit_hash.trim()
  if (!/^[a-f0-9]{40}$/i.test(commit_hash)) {
    throw createError({
      statusCode: 400,
      message: 'commit_hash debe ser un hash SHA-1 válido (40 caracteres hexadecimales)'
    })
  }

  // ── 4. Validar y normalizar opcionales numéricos ─────────────────────────
  let risk_score: number | null = null
  if (body.risk_score !== undefined && body.risk_score !== null) {
    const score = Number(body.risk_score)
    if (isNaN(score) || score < 0 || score > 100) {
      throw createError({ statusCode: 400, message: 'risk_score debe ser un número entre 0 y 100' })
    }
    risk_score = Math.round(score)
  }

  const intFields = ['lines_added', 'lines_deleted', 'files_modified'] as const
  const normalizedInts: Record<string, number> = {}
  for (const field of intFields) {
    if (body[field] !== undefined) {
      const val = Number(body[field])
      if (isNaN(val) || val < 0) {
        throw createError({ statusCode: 400, message: `${field} debe ser un número mayor o igual a 0` })
      }
      normalizedInts[field] = Math.round(val)
    }
  }

  // ── 5. Validar opcionales booleanos ──────────────────────────────────────
  const boolFields = ['tests_modified', 'complex_sql_added'] as const
  for (const field of boolFields) {
    if (body[field] !== undefined && typeof body[field] !== 'boolean') {
      throw createError({ statusCode: 400, message: `${field} debe ser un booleano` })
    }
  }

  // ── 6. Validar risk_label ────────────────────────────────────────────────
  const validLabels = ['low', 'medium', 'high', 'critical']
  if (body.risk_label !== undefined && body.risk_label !== null) {
    if (typeof body.risk_label !== 'string' || !validLabels.includes(body.risk_label)) {
      throw createError({
        statusCode: 400,
        message: `risk_label debe ser uno de: ${validLabels.join(', ')}`
      })
    }
  }

  // ── 7. Unicidad commit_hash ──────────────────────────────────────────────
  const existing = await db
    .select({ id: commit_analyses.id })
    .from(commit_analyses)
    .where(eq(commit_analyses.commit_hash, commit_hash))
    .limit(1)

  if (existing.length > 0) {
    throw createError({ statusCode: 409, message: 'El commit_hash ya fue analizado anteriormente' })
  }

  // ── 8. Insertar ──────────────────────────────────────────────────────────
  try {
    const newAnalysis = await db.insert(commit_analyses).values({
      commit_hash,
      user_id:           userId,
      risk_score:        risk_score,
      lines_added:       normalizedInts['lines_added']    ?? 0,
      lines_deleted:     normalizedInts['lines_deleted']  ?? 0,
      files_modified:    normalizedInts['files_modified'] ?? 0,
      tests_modified:    body.tests_modified              ?? false,
      complex_sql_added: body.complex_sql_added           ?? false,
      risk_label:        body.risk_label                  ?? null,
    }).returning()

    return { commit_analysis: newAnalysis[0] }

  } catch (error) {
    if ((error as any)?.code === '23505') {
      throw createError({ statusCode: 409, message: 'El commit_hash ya fue analizado anteriormente' })
    }
    if ((error as any)?.code === '23503') {
      throw createError({ statusCode: 400, message: 'El user_id proporcionado no existe' })
    }
    console.error('[commit-analyses.post] Error:', (error as any)?.message)
    throw createError({ statusCode: 500, message: 'No se pudo crear el análisis' })
  }
})