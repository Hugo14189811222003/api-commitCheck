// composables/useLogin.js
// Lógica completa del login y verificación 2FA

export function useLogin() {
    const router = useRouter()
  
    // ─── Estado general ───────────────────────────────────────────
    const step        = ref(1)
    const showPw      = ref(false)
    const isLoading   = ref(false)
    const loginError  = ref('')
    const otpError    = ref('')
  
    // ─── Credenciales ─────────────────────────────────────────────
    const credentials = reactive({ email: '', password: '' })
  
    // ─── OTP ──────────────────────────────────────────────────────
    const otp     = ref(Array(6).fill(''))
    const otpRefs = ref([])
    const timer   = ref(120)
    let timerInterval = null
  
    // ─── Computed ─────────────────────────────────────────────────
  
    // Enmascara el email para mostrarlo en el paso 2: "de***@empresa.com"
    const maskedEmail = computed(() => {
      const e = credentials.email || 'dev@empresa.com'
      const [user, domain] = e.split('@')
      return user.slice(0, 2) + '***@' + domain
    })
  
    // Formatea los segundos restantes como "M:SS"
    const timerFormatted = computed(() => {
      const m = Math.floor(timer.value / 60)
      const s = timer.value % 60
      return `${m}:${s.toString().padStart(2, '0')}`
    })
  
    // Verdadero cuando los 6 dígitos del OTP están llenos
    const otpFull = computed(() => otp.value.every(d => d !== ''))
  
    // ─── Timer del OTP ────────────────────────────────────────────
  
    function startTimer() {
      clearInterval(timerInterval)
      timer.value = 120
      timerInterval = setInterval(() => {
        if (timer.value > 0) timer.value--
        else clearInterval(timerInterval)
      }, 1000)
    }
  
    function resendCode() {
      startTimer()
      otp.value = Array(6).fill('')
      otpError.value = ''
      nextTick(() => otpRefs.value[0]?.focus())
    }
  
    // ─── Paso 1: Login ────────────────────────────────────────────
  
    async function handleLogin() {
      loginError.value = ''
  
      if (!credentials.email || !credentials.password) {
        loginError.value = 'Por favor completa todos los campos.'
        return
      }
      if (credentials.password.length < 6) {
        loginError.value = 'Contraseña demasiado corta.'
        return
      }
  
      isLoading.value = true
      // TODO: reemplazar con llamada real → await $fetch('/api/auth/login', { method: 'POST', body: credentials })
      await new Promise(r => setTimeout(r, 1200))
      isLoading.value = false
  
      step.value = 2
      startTimer()
      nextTick(() => otpRefs.value[0]?.focus())
    }
  
    // ─── Paso 2: Verificación 2FA ─────────────────────────────────
  
    async function handleVerify() {
      otpError.value = ''
      isLoading.value = true
      // TODO: reemplazar con llamada real → await $fetch('/api/auth/verify-otp', { method: 'POST', body: { code } })
      await new Promise(r => setTimeout(r, 1000))
      isLoading.value = false
  
      const code = otp.value.join('')
  
      // Demo: cualquier código excepto "000000" es válido
      if (code === '000000') {
        otpError.value = 'Código incorrecto. Por favor intenta nuevamente.'
        otp.value = Array(6).fill('')
        nextTick(() => otpRefs.value[0]?.focus())
        return
      }
  
      clearInterval(timerInterval)
      router.push('/dashboard')
    }
  
    // ─── Manejo de inputs del OTP ─────────────────────────────────
  
    // Al escribir un dígito, avanza al siguiente campo automáticamente
    function handleOtpInput(i, e) {
      const val = e.target.value.replace(/\D/g, '')
      otp.value[i] = val.slice(-1)
      if (val && i < 5) nextTick(() => otpRefs.value[i + 1]?.focus())
      if (otpFull.value) handleVerify()
    }
  
    // Al borrar un campo vacío, retrocede al campo anterior
    function handleOtpKeydown(i, e) {
      if (e.key === 'Backspace' && !otp.value[i] && i > 0) {
        nextTick(() => otpRefs.value[i - 1]?.focus())
      }
    }
  
    // Permite pegar los 6 dígitos de un solo golpe
    function handleOtpPaste(e) {
      e.preventDefault()
      const paste = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6)
      paste.split('').forEach((c, i) => { otp.value[i] = c })
      nextTick(() => {
        const next = Math.min(paste.length, 5)
        otpRefs.value[next]?.focus()
      })
    }
  
    // Limpia el intervalo al desmontar el componente
    onUnmounted(() => clearInterval(timerInterval))
  
    // ─── Exportar todo lo que necesita el template ────────────────
    return {
      // Estado
      step,
      showPw,
      isLoading,
      loginError,
      otpError,
      credentials,
      otp,
      otpRefs,
      timer,
      // Computed
      maskedEmail,
      timerFormatted,
      otpFull,
      // Funciones
      handleLogin,
      handleVerify,
      handleOtpInput,
      handleOtpKeydown,
      handleOtpPaste,
      resendCode,
    }
  }