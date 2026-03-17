// server/api/users.post.ts
import { db } from '../db'
import { users } from '../schema'
import { eq, or } from 'drizzle-orm'

export default defineEventHandler(async (event) => {
  const body = await readBody(event)

  // ── 1. Campos presentes ──────────────────────────────────────────────────
  const missingFields: string[] = []
  if (!body.username) missingFields.push('username')
  if (!body.email)    missingFields.push('email')
  if (!body.password) missingFields.push('password')

  if (missingFields.length > 0) {
    throw createError({
      statusCode: 400,
      message: `Campos requeridos faltantes: ${missingFields.join(', ')}`
    })
  }

  // ── 2. Tipos correctos ───────────────────────────────────────────────────
  if (typeof body.username !== 'string' ||
      typeof body.email    !== 'string' ||
      typeof body.password !== 'string') {
    throw createError({
      statusCode: 400,
      message: 'username, email y password deben ser strings'
    })
  }

  // ── 3. Trim y no vacíos ──────────────────────────────────────────────────
  const username = body.username.trim()
  const email    = body.email.trim().toLowerCase()
  const password = body.password  // no trim a passwords

  const emptyFields: string[] = []
  if (username.length === 0) emptyFields.push('username')
  if (email.length    === 0) emptyFields.push('email')
  if (password.length === 0) emptyFields.push('password')

  if (emptyFields.length > 0) {
    throw createError({
      statusCode: 400,
      message: `Los siguientes campos no pueden estar vacíos: ${emptyFields.join(', ')}`
    })
  }

  // ── 4. Longitudes ────────────────────────────────────────────────────────
  if (username.length < 3 || username.length > 30) {
    throw createError({
      statusCode: 400,
      message: 'username debe tener entre 3 y 30 caracteres'
    })
  }

  if (password.length < 8 || password.length > 72) {
    throw createError({
      statusCode: 400,
      message: 'password debe tener entre 8 y 72 caracteres'
    })
  }

  // ── 5. Formato username (solo letras, números, guion bajo) ───────────────
  if (!/^[a-zA-Z0-9_]+$/.test(username)) {
    throw createError({
      statusCode: 400,
      message: 'username solo puede contener letras, números y guiones bajos'
    })
  }

  // ── 6. Formato email ─────────────────────────────────────────────────────
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  if (!emailRegex.test(email)) {
    throw createError({
      statusCode: 400,
      message: 'El formato del email no es válido'
    })
  }

  // ── 7. Unicidad (username Y email en una sola query) ─────────────────────
  const existing = await db
    .select({ username: users.username, email: users.email })
    .from(users)
    .where(or(eq(users.username, username), eq(users.email, email)))
    .limit(1)

  if (existing.length > 0) {
    const taken = existing[0]!
    if (taken.username === username && taken.email === email) {
      throw createError({ statusCode: 409, message: 'username y email ya están en uso' })
    }
    if (taken.username === username) {
      throw createError({ statusCode: 409, message: 'El username ya está en uso' })
    }
    throw createError({ statusCode: 409, message: 'El email ya está registrado' })
  }

  // ── 8. Insertar ──────────────────────────────────────────────────────────
  try {
    const newUser = await db.insert(users).values({
      username,
      email,
      password,   // ⚠️  hashea el password antes con bcrypt/argon2 antes de llegar aquí
    }).returning()

    return { user: newUser[0] }

  } catch (error) {
    // Race condition: otro proceso insertó el mismo username/email entre la
    // verificación y el insert (unique constraint de la DB como red de seguridad)
    if ((error as any)?.code === '23505') {
      throw createError({
        statusCode: 409,
        message: 'username o email ya están en uso'
      })
    }

    console.error('[users.post] Error inesperado:', error)
    throw createError({
      statusCode: 500,
      message: 'No se pudo crear el usuario'
    })
  }
})