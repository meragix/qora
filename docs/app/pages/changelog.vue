<script setup lang="ts">
import type { ChangeType, MinimarkNode, ReleaseCard } from '~/utils/changelog'

// The packages' CHANGELOG.md files are the source: this page only lays them
// out. Entries stay in English on the French page; translating them would mean
// a second changelog to keep in sync.

const { locale } = useDocusI18n()
const route = useRoute()

const copy = {
  en: {
    title: 'Changelog',
    description: 'Every release of Qora and its DevTools, read from the CHANGELOG.md file of each package.',
    core: 'Qora',
    devtools: 'DevTools',
    coreHint: 'Since 1.0.0, qora, qora_flutter and qora_hooks are released together under the same version.',
    devtoolsHint: 'The DevTools packages have their own versions.',
    latest: 'Latest',
    compare: 'Compare changes',
    source: 'View source',
    types: { Added: 'Added', Changed: 'Changed', Deprecated: 'Deprecated', Removed: 'Removed', Fixed: 'Fixed', Security: 'Security' },
  },
  fr: {
    title: 'Journal des versions',
    description: 'Toutes les versions de Qora et de ses DevTools, lues depuis le fichier CHANGELOG.md de chaque paquet.',
    core: 'Qora',
    devtools: 'DevTools',
    coreHint: 'Depuis la 1.0.0, qora, qora_flutter et qora_hooks sortent ensemble, sous le même numéro de version. Les entrées sont en anglais.',
    devtoolsHint: 'Les paquets DevTools ont leurs propres versions. Les entrées sont en anglais.',
    latest: 'Dernière',
    compare: 'Comparer les changements',
    source: 'Voir la source',
    types: { Added: 'Ajouts', Changed: 'Modifications', Deprecated: 'Dépréciations', Removed: 'Suppressions', Fixed: 'Corrections', Security: 'Sécurité' },
  },
} as const

const t = computed(() => copy[locale.value as keyof typeof copy] ?? copy.en)

const typeStyle: Record<ChangeType, { color: 'success' | 'info' | 'warning' | 'error' | 'primary', icon: string }> = {
  Added: { color: 'success', icon: 'i-lucide-plus' },
  Changed: { color: 'info', icon: 'i-lucide-refresh-cw' },
  Deprecated: { color: 'warning', icon: 'i-lucide-clock-alert' },
  Removed: { color: 'error', icon: 'i-lucide-minus' },
  Fixed: { color: 'primary', icon: 'i-lucide-wrench' },
  Security: { color: 'error', icon: 'i-lucide-shield-alert' },
}

// Package directory under packages/ and its name, in display order.
const corePackages = [['dart', 'qora'], ['flutter', 'qora_flutter'], ['hooks', 'qora_hooks']] as const
const devtoolsPackages = [['devtools/overlay', 'qora_devtools_overlay'], ['devtools/shared', 'qora_devtools_shared']] as const
const sourceUrl = (pkg: string) => {
  const dir = [...corePackages, ...devtoolsPackages].find(([, name]) => name === pkg)?.[0]
  return `https://github.com/meragix/qora/blob/main/packages/${dir}/CHANGELOG.md`
}

const { data } = await useAsyncData('changelog', async () => {
  const files = await queryCollection('changelog').select('stem', 'body', 'rawbody').all()
  const byStem = new Map(files.map(f => [f.stem, f]))
  const issues: string[] = []

  const read = (packages: readonly (readonly [string, string])[]) => packages.map(([dir, pkg]) => {
    const file = byStem.get(`${dir}/CHANGELOG`)
    if (!file) {
      issues.push(`${pkg}: packages/${dir}/CHANGELOG.md is missing from the changelog collection`)
      return []
    }
    const parsed = parseChangelog(pkg, (file.body as unknown as { value: MinimarkNode[] }).value, file.rawbody)
    issues.push(...parsed.issues)
    if (parsed.releases.length === 0) issues.push(`${pkg}: no release found`)
    return parsed.releases
  })

  return {
    core: groupByVersion(read(corePackages), '1.0.0'),
    devtools: mergeByDate(read(devtoolsPackages)),
    issues,
  }
})

// Fails `nuxt generate` (nitro.prerender.failOnError) and shows the error in
// dev, instead of publishing a changelog with a release missing.
if (!data.value || data.value.issues.length > 0) {
  throw createError({
    statusCode: 500,
    statusMessage: `Unreadable CHANGELOG.md: ${data.value?.issues.join('; ') ?? 'no data'}`,
    fatal: true,
  })
}

useSeoMeta({
  title: () => t.value.title,
  ogTitle: () => t.value.title,
  description: () => t.value.description,
  ogDescription: () => t.value.description,
})

// Changelog dates are calendar days. Formatted in UTC so that the day does not
// shift in the reader's time zone, and the server and client render the same text.
const formatDate = (date: string) => new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium', timeZone: 'UTC' })
  .format(new Date(`${date}T00:00:00Z`))

const body = (nodes: MinimarkNode[]) => ({ body: { type: 'minimark', value: nodes } })

const timelines = computed(() => [
  { value: 'core' as const, cards: data.value!.core },
  { value: 'devtools' as const, cards: data.value!.devtools },
])

const tab = ref<'core' | 'devtools'>('core')
const tabs = computed(() => [
  { label: t.value.core, value: 'core', icon: 'i-lucide-package' },
  { label: t.value.devtools, value: 'devtools', icon: 'i-lucide-bug' },
])

// The static HTML always renders the Qora tab; a link to a DevTools release
// switches tab once hydrated, then scrolls to it.
onMounted(async () => {
  const hash = decodeURIComponent(route.hash.slice(1))
  const isDevtools = data.value!.devtools.some(card => card.id === hash)
  if (route.query.tab === 'devtools' || isDevtools) {
    tab.value = 'devtools'
    await nextTick()
    if (isDevtools) document.getElementById(hash)?.scrollIntoView()
  }
})

// Only the newest lockstep version: a single package card is never "the" latest.
const isLatest = (card: ReleaseCard, index: number) => index === 0 && !card.pkg
</script>

<template>
  <UContainer>
    <UPageHeader
      :title="t.title"
      :description="t.description"
    />

    <UPageBody>
      <div class="mx-auto mb-10 flex max-w-2xl flex-col gap-3 lg:ms-32 lg:ps-8 xl:mx-auto xl:ps-0">
        <UTabs
          v-model="tab"
          :items="tabs"
          :content="false"
          variant="pill"
          class="w-full sm:w-auto"
        />
        <p class="text-sm text-muted">
          {{ tab === 'core' ? t.coreHint : t.devtoolsHint }}
        </p>
      </div>

      <UChangelogVersions
        v-for="timeline in timelines"
        v-show="tab === timeline.value"
        :key="timeline.value"
      >
        <!-- UChangelogVersion does not pass an id to its root, so the anchor
             sits on a wrapper. -->
        <div
          v-for="(card, index) in timeline.cards"
          :id="card.id"
          :key="card.id"
          class="scroll-mt-24"
        >
          <UChangelogVersion
            :date="card.date"
            :badge="isLatest(card, index) ? { label: t.latest, color: 'primary', variant: 'subtle' } : undefined"
          >
            <template #date>
              {{ formatDate(card.date) }}
            </template>

            <template #title>
              <NuxtLink
                :to="`#${card.id}`"
                class="hover:text-primary"
              >
                <span
                  v-if="card.pkg"
                  class="font-mono"
                >{{ card.pkg }} </span>{{ card.version }}
              </NuxtLink>
            </template>

            <template #body>
              <div class="mt-4 flex flex-col gap-6">
                <div
                  v-for="release in card.packages"
                  :key="release.pkg"
                  class="flex flex-col gap-4"
                >
                  <!-- A lockstep card names each package; a single package
                       card already does in its title. -->
                  <div
                    v-if="!card.pkg"
                    class="flex items-center gap-2"
                  >
                    <UBadge
                      :label="release.pkg"
                      color="neutral"
                      variant="outline"
                      class="font-mono"
                    />
                    <span
                      v-if="release.date !== card.date"
                      class="text-xs text-muted"
                    >{{ formatDate(release.date) }}</span>
                  </div>

                  <section
                    v-for="section in release.sections"
                    :key="section.type"
                    class="changelog-section"
                  >
                    <UBadge
                      :label="t.types[section.type]"
                      :color="typeStyle[section.type].color"
                      :icon="typeStyle[section.type].icon"
                      variant="subtle"
                      size="sm"
                    />
                    <ContentRenderer :value="body(section.nodes)" />
                  </section>
                </div>
              </div>
            </template>

            <template #actions>
              <UButton
                :to="card.compareUrl ?? sourceUrl(card.packages[0]!.pkg)"
                target="_blank"
                :label="card.compareUrl ? t.compare : t.source"
                icon="i-simple-icons-github"
                color="neutral"
                variant="link"
                size="sm"
                class="px-0"
              />
            </template>
          </UChangelogVersion>
        </div>
      </UChangelogVersions>
    </UPageBody>
  </UContainer>
</template>

<style scoped>
/* Prose lists come with a top margin meant for running text; under a badge it
   only pushes the entries away from their label. */
.changelog-section :deep(ul) {
  margin-top: 0.5rem;
  margin-bottom: 0;
}
</style>
