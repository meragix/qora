export default defineNuxtConfig({
  extends: ['docus'],
  modules: ['@nuxtjs/i18n'],
  nitro: {
    prerender: {
      crawlLinks: true,
      routes: ['/en', '/fr'],
    },
  },
  site: {
    name: 'Qora',
    url: 'https://qora.meragix.dev',
  },
  // llms.txt and llms-full.txt for AI assistants. English only: the French
  // pages are translations and would double the size without adding facts.
  llms: {
    domain: 'https://qora.meragix.dev',
    title: 'Qora',
    description: 'Server-state library for Flutter and Dart: caching, background refresh, queries that pause offline, and a queue that replays writes on reconnect. Inspired by TanStack Query, with a different API and no code generation.',
    notes: [
      'Rules for coding assistants, with the most common mistakes: https://qora.meragix.dev/qora-rules.md',
      'Flutter apps depend on qora_flutter (it re-exports qora); hook users add qora_hooks.',
      'QoraState is sealed (Initial, Loading, Success, Failure): render it with an exhaustive switch. There is no state.when().',
      'Offline, queries pause: Loading with FetchStatus.paused, never Failure or Initial.',
      'invalidate() and MutationOptions.invalidates match exact keys; use invalidatePrefix() for a family of keys.',
    ],
    full: {
      title: 'Qora documentation',
      description: 'The complete English documentation of Qora.',
    },
    sections: [
      {
        title: 'Documentation',
        contentCollection: 'docs_en',
        contentFilters: [{ field: 'extension', operator: '=', value: 'md' }],
      },
    ],
  },
  i18n: {
    strategy: 'prefix',
    defaultLocale: 'en',
    locales: [
      { code: 'en', name: 'English' },
      { code: 'fr', name: 'Français' },
    ],
  },
  content: {
    build: {
      markdown: {
        highlight: {
          langs: [
            'dart',
            'mermaid',
          ]
        }
      }
    }
  }
})