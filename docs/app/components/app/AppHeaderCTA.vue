<script setup lang="ts">
// Overrides the empty AppHeaderCTA slot that Docus leaves to the site.
const { locale, localePath } = useDocusI18n()

const label = computed(() => locale.value === 'fr' ? 'Versions' : 'Changelog')
</script>

<template>
  <UButton
    :to="localePath('/changelog')"
    :label="label"
    :aria-label="label"
    icon="i-lucide-history"
    color="neutral"
    variant="ghost"
    :ui="{ label: 'hidden sm:inline' }"
  />
</template>
