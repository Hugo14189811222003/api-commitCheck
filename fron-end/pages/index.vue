<template>
  <div class="login-wrapper noise-bg">
    <!-- Fondo: cuadrícula + orbes -->
    <div class="bg-grid" aria-hidden="true"></div>
    <div class="orb orb-1" aria-hidden="true"></div>
    <div class="orb orb-2" aria-hidden="true"></div>

    <div class="login-container">

      <!-- Logo / Header -->
      <div class="login-header animate-fadeInUp">
        <div class="logo-mark">
          <svg width="36" height="36" viewBox="0 0 36 36" fill="none">
            <rect width="36" height="36" rx="8" fill="rgba(0,229,255,0.1)" stroke="rgba(0,229,255,0.3)" stroke-width="1"/>
            <path d="M10 12h6M10 18h10M10 24h8" stroke="#00e5ff" stroke-width="1.8" stroke-linecap="round"/>
            <circle cx="26" cy="12" r="3" fill="#00e5ff" opacity="0.9"/>
            <circle cx="26" cy="24" r="3" fill="#ff4757" opacity="0.9"/>
            <path d="M24 18h4" stroke="#ffb800" stroke-width="1.8" stroke-linecap="round"/>
          </svg>
        </div>
        <div class="logo-text">
          <span class="logo-name">Commit<span class="accent">Check</span></span>
          <span class="logo-tagline">Code Risk Analysis Platform</span>
        </div>
      </div>

      <!-- Card -->
      <div class="login-card glass animate-fadeInUp delay-1">

        <!-- Indicador de pasos -->
        <div class="step-indicator">
          <div class="step" :class="{ active: step >= 1, done: step > 1 }">
            <span class="step-num">{{ step > 1 ? '✓' : '01' }}</span>
            <span class="step-label">Credenciales</span>
          </div>
          <div class="step-line" :class="{ active: step > 1 }"></div>
          <div class="step" :class="{ active: step >= 2, done: step > 2 }">
            <span class="step-num">{{ step > 2 ? '✓' : '02' }}</span>
            <span class="step-label">Verificación</span>
          </div>
        </div>

        <!-- PASO 1: Login -->
        <Transition name="slide-step" mode="out-in">
          <div v-if="step === 1" key="step1" class="form-step">
            <div class="form-header">
              <h1>Iniciar sesión</h1>
              <p>Accede a tu cuenta de CommitCheck</p>
            </div>

            <div class="form-group">
              <label class="form-label">Usuario / Email</label>
              <div class="input-wrapper">
                <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                  <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                  <circle cx="12" cy="7" r="4"/>
                </svg>
                <input
                  v-model="credentials.email"
                  type="text"
                  class="input-field"
                  placeholder="dev@empresa.com"
                  @keydown.enter="handleLogin"
                  autocomplete="username"
                />
              </div>
            </div>

            <div class="form-group">
              <label class="form-label">
                Contraseña
                <a href="#" class="forgot-link">¿Olvidaste tu contraseña?</a>
              </label>
              <div class="input-wrapper">
                <svg class="input-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                  <rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
                  <path d="M7 11V7a5 5 0 0 1 10 0v4"/>
                </svg>
                <input
                  v-model="credentials.password"
                  :type="showPw ? 'text' : 'password'"
                  class="input-field"
                  placeholder="••••••••••"
                  @keydown.enter="handleLogin"
                  autocomplete="current-password"
                />
                <button class="pw-toggle" @click="showPw = !showPw" type="button" :aria-label="showPw ? 'Ocultar' : 'Mostrar'">
                  <svg v-if="!showPw" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                    <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                    <circle cx="12" cy="12" r="3"/>
                  </svg>
                  <svg v-else width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                    <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/>
                    <line x1="1" y1="1" x2="23" y2="23"/>
                  </svg>
                </button>
              </div>
            </div>

            <div v-if="loginError" class="error-msg animate-fadeIn">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10"/>
                <line x1="12" y1="8" x2="12" y2="12"/>
                <line x1="12" y1="16" x2="12.01" y2="16"/>
              </svg>
              {{ loginError }}
            </div>

            <button class="btn-primary w-full mt-4" @click="handleLogin" :disabled="isLoading">
              <svg v-if="!isLoading" width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
                <polyline points="10 17 15 12 10 7"/>
                <line x1="15" y1="12" x2="3" y2="12"/>
              </svg>
              <span v-if="isLoading" class="spinner"></span>
              {{ isLoading ? 'Verificando...' : 'Continuar' }}
            </button>

            <div class="divider"><span>acceso seguro con 2FA</span></div>

            <div class="security-badges">
              <span class="badge">
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
                TLS 1.3
              </span>
              <span class="badge">
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
                AES-256
              </span>
              <span class="badge">
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
                SOC 2
              </span>
            </div>
          </div>
        </Transition>

        <!-- PASO 2: Verificación 2FA -->
        <Transition name="slide-step" mode="out-in">
          <div v-if="step === 2" key="step2" class="form-step">
            <div class="form-header">
              <div class="otp-icon">
                <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--accent-primary)" stroke-width="1.5">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                  <polyline points="9 12 11 14 15 10"/>
                </svg>
              </div>
              <h1>Verificación 2FA</h1>
              <p>Ingresa el código de 6 dígitos enviado a <strong>{{ maskedEmail }}</strong></p>
            </div>

            <!-- Inputs OTP -->
            <div class="otp-container">
              <input
                v-for="(_, i) in 6"
                :key="i"
                :ref="el => { if (el) otpRefs[i] = el }"
                v-model="otp[i]"
                type="text"
                inputmode="numeric"
                maxlength="1"
                class="otp-input"
                :class="{ filled: otp[i], error: otpError }"
                @input="handleOtpInput(i, $event)"
                @keydown="handleOtpKeydown(i, $event)"
                @paste="handleOtpPaste($event)"
              />
            </div>

            <div v-if="otpError" class="error-msg animate-fadeIn">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="10"/>
                <line x1="12" y1="8" x2="12" y2="12"/>
                <line x1="12" y1="16" x2="12.01" y2="16"/>
              </svg>
              {{ otpError }}
            </div>

            <!-- Timer -->
            <div class="otp-timer">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                <circle cx="12" cy="12" r="10"/>
                <polyline points="12 6 12 12 16 14"/>
              </svg>
              <span v-if="timer > 0">El código expira en <strong>{{ timerFormatted }}</strong></span>
              <button v-else class="resend-btn" @click="resendCode">Reenviar código</button>
            </div>

            <button class="btn-primary w-full mt-4" @click="handleVerify" :disabled="isLoading || !otpFull">
              <span v-if="isLoading" class="spinner"></span>
              <svg v-else width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <polyline points="20 6 9 17 4 12"/>
              </svg>
              {{ isLoading ? 'Verificando...' : 'Verificar acceso' }}
            </button>

            <button class="back-btn" @click="step = 1; otpError = ''; otp = Array(6).fill('')">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="15 18 9 12 15 6"/>
              </svg>
              Volver al login
            </button>
          </div>
        </Transition>

      </div>

      <!-- Footer -->
      <div class="login-footer animate-fadeInUp delay-3">
        <span>CommitCheck v2.4.0</span>
        <span class="dot">·</span>
        <span>© 2025 Todos los derechos reservados</span>
      </div>

    </div>
  </div>
</template>

<script setup>
// Metadatos de la página (sin layout)
definePageMeta({ layout: false })

// Importá toda la lógica desde el composable
import { useLogin } from '~/composables/useLogin.js'

const {
  step, showPw, isLoading, loginError, otpError,
  credentials, otp, otpRefs, timer,
  maskedEmail, timerFormatted, otpFull,
  handleLogin, handleVerify,
  handleOtpInput, handleOtpKeydown, handleOtpPaste,
  resendCode,
} = useLogin()
</script>

<style>
/* Importa los estilos específicos de esta página */
@import '~/assets/login.css';
</style>
