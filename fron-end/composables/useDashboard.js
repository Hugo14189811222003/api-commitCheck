// composables/useDashboard.js
// Lógica completa del Dashboard: navegación, stats, commits y análisis

export function useDashboard() {
    const router = useRouter()
  
    // ─── Estado de la UI ──────────────────────────────────────────
    const activeNav      = ref('overview')
    const searchQuery    = ref('')
    const riskFilter     = ref('')
    const selectedCommit = ref(null)
  
    // ─── Etiquetas y colores de riesgo ────────────────────────────
  
    const riskLabels = { low: 'Bajo', medium: 'Medio', high: 'Alto' }
  
    // Devuelve el color CSS según el score (0-100)
    function riskColor(score) {
      if (score < 35) return 'var(--accent-success)'
      if (score < 65) return 'var(--accent-warning)'
      return 'var(--accent-danger)'
    }
  
    // ─── Navegación del sidebar ───────────────────────────────────
  
    const navItems = [
      {
        id: 'overview',
        label: 'Overview',
        badge: null,
        icon: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>',
      },
      {
        id: 'commits',
        label: 'Commits',
        badge: '3',
        icon: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="4"/><line x1="1.05" y1="12" x2="7" y2="12"/><line x1="17.01" y1="12" x2="22.96" y2="12"/></svg>',
      },
      {
        id: 'history',
        label: 'Historial',
        badge: null,
        icon: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="12 8 12 12 14 14"/><path d="M3.05 11a9 9 0 1 1 .5 4m-.5 5v-5h5"/></svg>',
      },
      {
        id: 'team',
        label: 'Equipo',
        badge: null,
        icon: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
      },
    ]
  
    const navAnalysis = [
      {
        id: 'security',
        label: 'Seguridad',
        icon: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
      },
      {
        id: 'structure',
        label: 'Estructura',
        icon: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>',
      },
      {
        id: 'performance',
        label: 'Rendimiento',
        icon: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>',
      },
      {
        id: 'settings',
        label: 'Configuración',
        icon: '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="3"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14M4.93 4.93a10 10 0 0 0 0 14.14"/></svg>',
      },
    ]
  
    // Título de la página según la sección activa
    const currentPageTitle = computed(() => {
      const all = [...navItems, ...navAnalysis]
      return all.find(n => n.id === activeNav.value)?.label || 'Dashboard'
    })
  
    // ─── Tarjetas de estadísticas ─────────────────────────────────
  
    const stats = [
      {
        label: 'Commits hoy',
        value: '24',
        icon: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><circle cx="12" cy="12" r="4"/><line x1="1.05" y1="12" x2="7" y2="12"/><line x1="17.01" y1="12" x2="22.96" y2="12"/></svg>',
        iconBg: 'rgba(0,229,255,0.1)',
        iconColor: 'var(--accent-primary)',
        trend: '+12%',
        trendUp: true,
      },
      {
        label: 'Alto riesgo',
        value: '3',
        icon: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
        iconBg: 'rgba(255,71,87,0.1)',
        iconColor: 'var(--accent-danger)',
        trend: '-25%',
        trendUp: false,
      },
      {
        label: 'Score promedio',
        value: '41',
        icon: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>',
        iconBg: 'rgba(255,184,0,0.1)',
        iconColor: 'var(--accent-warning)',
        trend: '-8%',
        trendUp: false,
      },
      {
        label: 'Revisados',
        value: '18',
        icon: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="20 6 9 17 4 12"/></svg>',
        iconBg: 'rgba(0,214,143,0.1)',
        iconColor: 'var(--accent-success)',
        trend: '+5%',
        trendUp: true,
      },
    ]
  
    // ─── Datos de commits (demo) ──────────────────────────────────
    // TODO: reemplazar con → const { data: commits } = await useFetch('/api/commits')
  
    const commits = [
      {
        hash: 'a3f92c1',
        message: 'feat: add JWT authentication middleware',
        author: 'María García',
        avatarColor: '#7c5cfc',
        time: 'hace 12 min',
        added: 142,
        removed: 8,
        risk: 'high',
        score: 78,
        categories: [
          {
            name: 'Seguridad',
            score: 82,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
            desc: 'Se detectaron patrones de autenticación sin validación de expiración de tokens.',
          },
          {
            name: 'Estructura',
            score: 55,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>',
            desc: 'Funciones con más de 50 líneas detectadas. Considerar refactorizar.',
          },
          {
            name: 'Cobertura',
            score: 30,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>',
            desc: 'Sin archivos de tests modificados. Se recomienda agregar pruebas unitarias.',
          },
          {
            name: 'Rendimiento',
            score: 65,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>',
            desc: 'Impacto moderado en tiempo de respuesta del middleware.',
          },
        ],
        warnings: [
          { level: 'high',   msg: 'Sin archivos de prueba modificados (+142 líneas)' },
          { level: 'high',   msg: 'Validación de expiración de JWT ausente' },
          { level: 'medium', msg: 'Función handleAuth supera 50 líneas' },
          { level: 'low',    msg: 'Documentación JSDoc incompleta' },
        ],
      },
      {
        hash: 'b7d14e8',
        message: 'fix: resolve null pointer in user service',
        author: 'Carlos López',
        avatarColor: '#00e5ff',
        time: 'hace 45 min',
        added: 12,
        removed: 5,
        risk: 'low',
        score: 18,
        categories: [
          {
            name: 'Seguridad',
            score: 15,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
            desc: 'Sin cambios en lógica de autenticación o autorización.',
          },
          {
            name: 'Cobertura',
            score: 20,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>',
            desc: 'Se actualizó el test de la función afectada.',
          },
          {
            name: 'Rendimiento',
            score: 10,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>',
            desc: 'Cambio minimal, sin impacto en rendimiento.',
          },
        ],
        warnings: [
          { level: 'low', msg: 'Cambio pequeño, parece seguro' },
        ],
      },
      {
        hash: 'c2e83f5',
        message: 'refactor: optimize DB queries in reports module',
        author: 'Ana Martínez',
        avatarColor: '#00d68f',
        time: 'hace 1h',
        added: 87,
        removed: 43,
        risk: 'medium',
        score: 52,
        categories: [
          {
            name: 'Base de Datos',
            score: 68,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>',
            desc: 'Consultas SQL complejas detectadas sin índices declarados.',
          },
          {
            name: 'Estructura',
            score: 44,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>',
            desc: 'Refactorización bien estructurada con separación de responsabilidades.',
          },
          {
            name: 'Cobertura',
            score: 55,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>',
            desc: 'Algunos casos de prueba actualizados pero falta cobertura de edge cases.',
          },
        ],
        warnings: [
          { level: 'medium', msg: '3 queries sin índice explícito' },
          { level: 'medium', msg: 'Falta cobertura en edge cases de paginación' },
          { level: 'low',    msg: 'Considera agregar comentarios en queries complejas' },
        ],
      },
      {
        hash: 'd9a61b2',
        message: 'chore: update dependencies and remove unused imports',
        author: 'Luis Torres',
        avatarColor: '#ffb800',
        time: 'hace 2h',
        added: 3,
        removed: 22,
        risk: 'low',
        score: 12,
        categories: [
          {
            name: 'Seguridad',
            score: 10,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
            desc: 'Limpieza de código, sin cambios de seguridad.',
          },
          {
            name: 'Estructura',
            score: 12,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/></svg>',
            desc: 'Código limpio, imports organizados correctamente.',
          },
        ],
        warnings: [
          { level: 'low', msg: 'Cambio de mantenimiento, bajo riesgo' },
        ],
      },
      {
        hash: 'e1c47d9',
        message: 'feat: implement bulk export endpoint for analytics',
        author: 'María García',
        avatarColor: '#7c5cfc',
        time: 'hace 3h',
        added: 234,
        removed: 12,
        risk: 'high',
        score: 85,
        categories: [
          {
            name: 'Seguridad',
            score: 90,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>',
            desc: 'Endpoint sin rate limiting ni autorización de roles detectado.',
          },
          {
            name: 'Rendimiento',
            score: 88,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>',
            desc: 'Exportación masiva sin paginación puede causar timeouts en producción.',
          },
          {
            name: 'Cobertura',
            score: 15,
            icon: '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>',
            desc: 'Sin ninguna prueba agregada para 234 líneas nuevas.',
          },
        ],
        warnings: [
          { level: 'high',   msg: 'Endpoint sin autenticación de roles' },
          { level: 'high',   msg: 'Sin rate limiting en operación costosa' },
          { level: 'high',   msg: 'Sin tests para 234 líneas de código nuevo' },
          { level: 'medium', msg: 'Exportación puede agotar memoria del servidor' },
        ],
      },
    ]
  
    // ─── Computed ─────────────────────────────────────────────────
  
    // Filtra commits según búsqueda de texto y nivel de riesgo
    const filteredCommits = computed(() => {
      return commits.filter(c => {
        const q = searchQuery.value.toLowerCase()
        const matchSearch =
          !q ||
          c.message.toLowerCase().includes(q) ||
          c.hash.includes(q) ||
          c.author.toLowerCase().includes(q)
        const matchRisk = !riskFilter.value || c.risk === riskFilter.value
        return matchSearch && matchRisk
      })
    })
  
    // ─── Acciones ─────────────────────────────────────────────────
  
    // Selecciona o deselecciona un commit al hacer click
    function selectCommit(commit) {
      selectedCommit.value =
        selectedCommit.value?.hash === commit.hash ? null : commit
    }
  
    // Cierra sesión y regresa al login
    function handleLogout() {
      router.push('/')
    }
  
    // ─── Exportar todo lo que necesita el template ────────────────
    return {
      // Estado
      activeNav,
      searchQuery,
      riskFilter,
      selectedCommit,
      // Datos estáticos
      riskLabels,
      navItems,
      navAnalysis,
      stats,
      // Computed
      currentPageTitle,
      filteredCommits,
      // Funciones
      riskColor,
      selectCommit,
      handleLogout,
    }
  }