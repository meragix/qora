import { defineContentConfig, defineCollection, z } from '@nuxt/content'
import { useNuxt } from '@nuxt/kit'
import { resolve } from 'pathe'

// Merged with the collections of the Docus layer (docs_<locale>, landing_<locale>).
//
// The changelog page reads the packages' CHANGELOG.md files in place: they stay
// the single source of truth, edited by hand and by scripts/release.sh. Only the
// published packages are listed.
const { options } = useNuxt()

export default defineContentConfig({
  collections: {
    changelog: defineCollection({
      type: 'page',
      source: {
        cwd: resolve(options.rootDir, '../packages'),
        include: '{dart,flutter,hooks,devtools/shared,devtools/overlay}/CHANGELOG.md',
      },
      // MDC reads `[1.4.0]` in a heading as a span, so the compare links defined
      // at the bottom of a file never reach the parsed body; they are read from
      // the raw text instead.
      schema: z.object({ rawbody: z.string() }),
    }),
  },
})
