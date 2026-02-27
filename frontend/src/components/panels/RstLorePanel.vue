<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">RST Lore</div>
    </header>
    <div class="panel-body">
      <div class="placeholder">
        <div class="placeholder-icon">??</div>
        <div>RST Lore 编辑器将在 M3 中实现</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts"></script>

<style scoped lang="scss">
.panel {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 16px;
  color: var(--rst-text-primary);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--rst-border-color);
}

.panel-title {
  font-size: 14px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.panel-body {
  margin-top: 12px;
  flex: 1;
}

.placeholder {
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  color: var(--rst-text-secondary);
  text-align: center;
}

.placeholder-icon {
  font-size: 24px;
}
</style>
