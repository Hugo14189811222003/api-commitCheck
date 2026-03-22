<template>
    <div class="dashboard-wrapper noise-bg">
      <div class="bg-grid" aria-hidden="true"></div>
  
      <!-- ── Sidebar ──────────────────────────────────────────── -->
      <aside class="sidebar glass">
        <div class="sidebar-logo">
          <svg width="28" height="28" viewBox="0 0 36 36" fill="none">
            <rect width="36" height="36" rx="8" fill="rgba(0,229,255,0.1)" stroke="rgba(0,229,255,0.3)" stroke-width="1"/>
            <path d="M10 12h6M10 18h10M10 24h8" stroke="#00e5ff" stroke-width="1.8" stroke-linecap="round"/>
            <circle cx="26" cy="12" r="3" fill="#00e5ff" opacity="0.9"/>
            <circle cx="26" cy="24" r="3" fill="#ff4757" opacity="0.9"/>
            <path d="M24 18h4" stroke="#ffb800" stroke-width="1.8" stroke-linecap="round"/>
          </svg>
          <span class="sidebar-brand">Commit<span class="accent">Check</span></span>
        </div>
  
        <nav class="sidebar-nav">
          <div class="nav-section-label">Principal</div>
          <button
            v-for="item in navItems"
            :key="item.id"
            class="nav-item"
            :class="{ active: activeNav === item.id }"
            @click="activeNav = item.id"
          >
            <span class="nav-icon" v-html="item.icon"></span>
            <span>{{ item.label }}</span>
            <span v-if="item.badge" class="nav-badge">{{ item.badge }}</span>
          </button>
  
          <div class="nav-section-label mt">Análisis</div>
          <button
            v-for="item in navAnalysis"
            :key="item.id"
            class="nav-item"
            :class="{ active: activeNav === item.id }"
            @click="activeNav = item.id"
          >
            <span class="nav-icon" v-html="item.icon"></span>
            <span>{{ item.label }}</span>
          </button>
        </nav>
  
        <div class="sidebar-user">
          <div class="user-avatar">JD</div>
          <div class="user-info">
            <span class="user-name">Juan Dev</span>
            <span class="user-role">Senior Developer</span>
          </div>
          <button class="logout-btn" @click="handleLogout" title="Cerrar sesión">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
              <polyline points="16 17 21 12 16 7"/>
              <line x1="21" y1="12" x2="9" y2="12"/>
            </svg>
          </button>
        </div>
      </aside>
  
      <!-- ── Contenido principal ───────────────────────────────── -->
      <main class="main-content">
  
        <!-- Topbar -->
        <header class="topbar">
          <div class="topbar-left">
            <h2 class="page-title">{{ currentPageTitle }}</h2>
            <div class="breadcrumb">
              <span>commitcheck</span>
              <span class="sep">/</span>
              <span class="current">{{ activeNav }}</span>
            </div>
          </div>
          <div class="topbar-right">
            <div class="repo-selector">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                <path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"/>
              </svg>
              <span>empresa/core-api</span>
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="6 9 12 15 18 9"/>
              </svg>
            </div>
            <button class="icon-btn" title="Notificaciones">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
                <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/>
                <path d="M13.73 21a2 2 0 0 1-3.46 0"/>
              </svg>
              <span class="notif-dot"></span>
            </button>
          </div>
        </header>
  
        <!-- Fila de estadísticas -->
        <section class="stats-row">
          <div
            v-for="(stat, i) in stats"
            :key="stat.label"
            class="stat-card glass animate-fadeInUp"
            :style="`animation-delay: ${i * 0.06}s`"
          >
            <div class="stat-icon" :style="`background: ${stat.iconBg}; color: ${stat.iconColor}`" v-html="stat.icon"></div>
            <div class="stat-body">
              <span class="stat-value">{{ stat.value }}</span>
              <span class="stat-label">{{ stat.label }}</span>
            </div>
            <div class="stat-trend" :class="stat.trendUp ? 'up' : 'down'">
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <polyline :points="stat.trendUp ? '23 6 13.5 15.5 8.5 10.5 1 18' : '23 18 13.5 8.5 8.5 13.5 1 6'"/>
              </svg>
              {{ stat.trend }}
            </div>
          </div>
        </section>
  
        <!-- Grid principal: commits + panel -->
        <div class="content-grid">
  
          <!-- Lista de commits recientes -->
          <section class="commits-section">
            <div class="section-header">
              <h3>Commits Recientes</h3>
              <div class="section-actions">
                <div class="search-bar">
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="11" cy="11" r="8"/>
                    <line x1="21" y1="21" x2="16.65" y2="16.65"/>
                  </svg>
                  <input v-model="searchQuery" placeholder="Buscar commit..." class="search-input" />
                </div>
                <select v-model="riskFilter" class="filter-select">
                  <option value="">Todo</option>
                  <option value="low">Bajo riesgo</option>
                  <option value="medium">Riesgo medio</option>
                  <option value="high">Alto riesgo</option>
                </select>
              </div>
            </div>
  
            <div class="commits-list">
              <div
                v-for="(commit, i) in filteredCommits"
                :key="commit.hash"
                class="commit-row glass animate-fadeInUp"
                :style="`animation-delay: ${i * 0.04}s`"
                :class="{ selected: selectedCommit?.hash === commit.hash }"
                @click="selectCommit(commit)"
              >
                <div class="commit-left">
                  <div class="commit-avatar" :style="`background: ${commit.avatarColor}`">
                    {{ commit.author[0] }}
                  </div>
                  <div class="commit-info">
                    <span class="commit-msg">{{ commit.message }}</span>
                    <div class="commit-meta">
                      <code class="commit-hash">{{ commit.hash }}</code>
                      <span>{{ commit.author }}</span>
                      <span>{{ commit.time }}</span>
                    </div>
                  </div>
                </div>
                <div class="commit-right">
                  <div class="commit-stats">
                    <span class="lines-added">+{{ commit.added }}</span>
                    <span class="lines-removed">-{{ commit.removed }}</span>
                  </div>
                  <span class="risk-chip" :class="`risk-${commit.risk}`">
                    <span class="risk-dot"></span>
                    {{ riskLabels[commit.risk] }}
                  </span>
                  <div class="risk-score" :style="`color: ${riskColor(commit.score)}`">
                    {{ commit.score }}
                  </div>
                </div>
              </div>
            </div>
          </section>
  
          <!-- Panel de análisis del commit seleccionado -->
          <aside class="analysis-panel">
  
            <!-- Detalle del commit -->
            <div v-if="selectedCommit" class="panel-section glass animate-fadeIn">
              <div class="panel-header">
                <h4>Análisis del Commit</h4>
                <code class="commit-hash-lg">{{ selectedCommit.hash }}</code>
              </div>
  
              <!-- Anillo de score -->
              <div class="score-display">
                <svg class="score-ring" viewBox="0 0 120 120">
                  <circle cx="60" cy="60" r="50" fill="none" stroke="var(--bg-base)" stroke-width="8"/>
                  <circle
                    cx="60" cy="60" r="50"
                    fill="none"
                    :stroke="riskColor(selectedCommit.score)"
                    stroke-width="8"
                    stroke-linecap="round"
                    stroke-dasharray="314"
                    :stroke-dashoffset="314 - (314 * selectedCommit.score / 100)"
                    transform="rotate(-90 60 60)"
                    style="transition: stroke-dashoffset 0.8s ease"
                  />
                </svg>
                <div class="score-inner">
                  <span class="score-num" :style="`color: ${riskColor(selectedCommit.score)}`">
                    {{ selectedCommit.score }}
                  </span>
                  <span class="score-label">Riesgo</span>
                </div>
              </div>
  
              <!-- Categorías: Seguridad, Estructura, Cobertura, etc. -->
              <div class="categories-list">
                <div v-for="cat in selectedCommit.categories" :key="cat.name" class="category-item">
                  <div class="cat-header">
                    <div class="cat-left">
                      <span class="cat-icon" v-html="cat.icon"></span>
                      <span class="cat-name">{{ cat.name }}</span>
                    </div>
                    <span class="cat-score" :style="`color: ${riskColor(cat.score)}`">{{ cat.score }}/100</span>
                  </div>
                  <div class="cat-bar-bg">
                    <div
                      class="cat-bar-fill"
                      :style="`width: ${cat.score}%; background: ${riskColor(cat.score)}`"
                    ></div>
                  </div>
                  <p class="cat-desc">{{ cat.desc }}</p>
                </div>
              </div>
            </div>
  
            <!-- Alertas detectadas -->
            <div v-if="selectedCommit" class="panel-section glass animate-fadeIn delay-2">
              <div class="panel-header">
                <h4>Alertas detectadas</h4>
              </div>
              <div class="warnings-list">
                <div
                  v-for="w in selectedCommit.warnings"
                  :key="w.msg"
                  class="warning-item"
                  :class="w.level"
                >
                  <svg v-if="w.level === 'high'" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
                    <line x1="12" y1="9" x2="12" y2="13"/>
                    <line x1="12" y1="17" x2="12.01" y2="17"/>
                  </svg>
                  <svg v-else-if="w.level === 'medium'" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="10"/>
                    <line x1="12" y1="8" x2="12" y2="12"/>
                    <line x1="12" y1="16" x2="12.01" y2="16"/>
                  </svg>
                  <svg v-else width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="20 6 9 17 4 12"/>
                  </svg>
                  <span>{{ w.msg }}</span>
                </div>
              </div>
            </div>
  
            <!-- Estado vacío -->
            <div v-if="!selectedCommit" class="empty-panel glass">
              <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="var(--text-muted)" stroke-width="1.2">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                <polyline points="14 2 14 8 20 8"/>
                <line x1="16" y1="13" x2="8" y2="13"/>
                <line x1="16" y1="17" x2="8" y2="17"/>
                <polyline points="10 9 9 9 8 9"/>
              </svg>
              <p>Selecciona un commit para ver su análisis detallado</p>
            </div>
  
          </aside>
        </div>
      </main>
    </div>
  </template>
  
  <script setup>
  // Metadatos de la página (sin layout)
  definePageMeta({ layout: false })
  
  // Importá toda la lógica desde el composable
  import { useDashboard } from '~/composables/useDashboard.js'
  
  const {
    activeNav, searchQuery, riskFilter, selectedCommit,
    riskLabels, navItems, navAnalysis, stats,
    currentPageTitle, filteredCommits,
    riskColor, selectCommit, handleLogout,
  } = useDashboard()
  </script>
  
  <style>
  /* Importa los estilos específicos de esta página */
  @import '~/assets/dashboard.css';
  </style>