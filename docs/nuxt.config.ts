export default defineNuxtConfig({
  extends: ['docus'],
  modules: ['@nuxtjs/i18n'],
   site: {
    name: 'Qora',
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