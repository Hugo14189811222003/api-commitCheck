import { db } from '../../db';
import { commit_analyses } from '../../schema';
import { eq } from 'drizzle-orm';

export default defineEventHandler(async (event) => {
  // ── 1. ID del param ──────────────────────────────────────────────────────
  const id = Number(getRouterParam(event, 'id'))
  if (!Number.isInteger(id) || id <= 0) {
    throw createError({ statusCode: 400, message: 'El id debe ser un entero positivo' })
  }

  const body = await readBody(event)

  // ── 2. Body no vacío ─────────────────────────────────────────────────────
  const allowedFields = [
    'risk_score', 'lines_added', 'lines_deleted',
    'files_modified', 'tests_modified', 'complex_sql_added', 'risk_label'
  ]
  const providedFields = Object.keys(body).filter(k => allowedFields.includes(k))

  if (providedFields.length === 0) {
    throw createError({
      statusCode: 400,
      message: `Debes enviar al menos uno de: ${allowedFields.join(', ')}`
    })
  }

  // ── 3. Validar y normalizar cada campo presente ───────────────────────────
  let risk_score: number | undefined = undefined
  if (body.risk_score !== undefined) {
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

  const boolFields = ['tests_modified', 'complex_sql_added'] as const
  for (const field of boolFields) {
    if (body[field] !== undefined && typeof body[field] !== 'boolean') {
      throw createError({ statusCode: 400, message: `${field} debe ser un booleano` })
    }
  }

  // ── 4. Validar risk_label ────────────────────────────────────────────────
  const validLabels = ['low', 'medium', 'high', 'critical']
  if (body.risk_label !== undefined && body.risk_label !== null) {
    if (typeof body.risk_label !== 'string' || !validLabels.includes(body.risk_label)) {
      throw createError({
        statusCode: 400,
        message: `risk_label debe ser uno de: ${validLabels.join(', ')}`
      })
    }
  }

  // ── 5. Verificar que el registro existe ──────────────────────────────────
  const existing = await db
    .select({ id: commit_analyses.id })
    .from(commit_analyses)
    .where(eq(commit_analyses.id, id))
    .limit(1)

  if (existing.length === 0) {
    throw createError({ statusCode: 404, message: `No existe un análisis con id ${id}` })
  }

  // ── 6. Actualizar ────────────────────────────────────────────────────────
  try {
    const updated = await db
      .update(commit_analyses)
      .set({
        ...(risk_score                          !== undefined && { risk_score }),
        ...(normalizedInts['lines_added']       !== undefined && { lines_added:    normalizedInts['lines_added'] }),
        ...(normalizedInts['lines_deleted']     !== undefined && { lines_deleted:  normalizedInts['lines_deleted'] }),
        ...(normalizedInts['files_modified']    !== undefined && { files_modified: normalizedInts['files_modified'] }),
        ...(body.tests_modified    !== undefined && { tests_modified:    body.tests_modified }),
        ...(body.complex_sql_added !== undefined && { complex_sql_added: body.complex_sql_added }),
        ...(body.risk_label        !== undefined && { risk_label:        body.risk_label }),
      })
      .where(eq(commit_analyses.id, id))
      .returning()

    return { commit_analysis: updated[0] }

  } catch (error) {
    console.error('[commit-analyses.put] Error:', (error as any)?.message)
    throw createError({ statusCode: 500, message: 'No se pudo actualizar el análisis' })
  }
})