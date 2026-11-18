// Turns the packages' CHANGELOG.md files, parsed by Nuxt Content into a
// minimark tree, into the cards of the changelog page. The files follow Keep a
// Changelog: `## [x.y.z] - YYYY-MM-DD` opens a release and
// `### Added|Changed|...` opens a section.
//
// Anything that does not fit is returned as an issue instead of being skipped,
// and the page fails the docs build on it: a typo in a heading must not make a
// release disappear from the site without anyone noticing.

export type MinimarkNode = string | [string, Record<string, unknown>, ...MinimarkNode[]]

// Keep a Changelog order, which is also the order sections render in.
export const CHANGE_TYPES = ['Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security'] as const
export type ChangeType = typeof CHANGE_TYPES[number]

export interface ChangelogSection {
  type: ChangeType
  nodes: MinimarkNode[]
}

export interface PackageRelease {
  pkg: string
  version: string
  date: string
  sections: ChangelogSection[]
  // Content between the release heading and its first section.
  notes: MinimarkNode[]
  compareUrl?: string
}

export interface ParsedChangelog {
  releases: PackageRelease[]
  issues: string[]
}

const VERSION = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/
// Checked on the raw text: MDC drops the brackets of `[1.4.0]` from the parsed
// heading, so only the source tells `## [1.4.0] - ...` from `## 1.4.0 - ...`.
const RAW_RELEASE_HEADING = /^## (?:\[Unreleased\]|\[([^\]]+)\] - (\d{4}-\d{2}-\d{2}))$/
const LINK_DEFINITION = /^\[([^\]]+)\]:\s*(\S+)\s*$/gm
// The only release body allowed without a section: a lockstep release that did
// not change this package.
const NO_CHANGES = /^No changes in this package\b[^\n]*$/

export function nodeText(node: MinimarkNode): string {
  if (typeof node === 'string') return node
  const [, , ...children] = node
  return children.map(nodeText).join('')
}

function tagOf(node: MinimarkNode): string | undefined {
  return typeof node === 'string' ? undefined : node[0]
}

function isValidDate(date: string): boolean {
  const parsed = new Date(`${date}T00:00:00Z`)
  return !Number.isNaN(parsed.getTime()) && parsed.toISOString().startsWith(date)
}

// The `##` lines of the raw file, outside code fences, each checked against the
// Keep a Changelog form.
function checkRawHeadings(pkg: string, rawbody: string, issues: string[]): number {
  // A fence closes only on the same character, at least as long as its opener.
  let fence: string | undefined
  let count = 0
  // Headings in an HTML comment (a draft commented out) are not rendered.
  const visible = rawbody.replace(/<!--[\s\S]*?-->/g, '')
  for (const line of visible.split('\n')) {
    const marker = /^ {0,3}(`{3,}|~{3,})/.exec(line)?.[1]
    if (marker) {
      if (!fence) fence = marker
      else if (marker[0] === fence[0] && marker.length >= fence.length) fence = undefined
      continue
    }
    if (fence || !/^## /.test(line)) continue
    count++
    const match = RAW_RELEASE_HEADING.exec(line.trimEnd())
    if (!match) {
      issues.push(`${pkg}: heading "${line.trim()}" is not "## [x.y.z] - YYYY-MM-DD" or "## [Unreleased]"`)
    }
    else if (match[1] !== undefined && (!VERSION.test(match[1]) || !isValidDate(match[2]!))) {
      issues.push(`${pkg}: heading "${line.trim()}" has an invalid version or date`)
    }
  }
  return count
}

export function parseChangelog(pkg: string, body: MinimarkNode[], rawbody: string): ParsedChangelog {
  const issues: string[] = []
  const links = new Map<string, string>()
  for (const [, label, url] of rawbody.matchAll(LINK_DEFINITION)) {
    links.set(label!.toLowerCase(), url!)
  }

  const releases: PackageRelease[] = []
  // The release being read; undefined above the first `##` and under
  // [Unreleased], whose content is not shown.
  let release: PackageRelease | undefined
  let section: ChangelogSection | undefined
  let inUnreleased = false
  let headingCount = 0

  for (const node of body) {
    const tag = tagOf(node)

    // Above the first `##`, only the title and an intro are expected; entries
    // there belong to no release and would never be released.
    if (headingCount === 0 && (tag === 'h3' || tag === 'ul' || tag === 'ol')) {
      issues.push(`${pkg}: "${nodeText(node).trim().slice(0, 60)}" is above the first "## " heading`)
      continue
    }

    if (tag === 'h2') {
      headingCount++
      release = undefined
      section = undefined
      inUnreleased = false
      const text = nodeText(node).trim()
      if (/^unreleased$/i.test(text)) {
        inUnreleased = true
        continue
      }
      const [version, date] = text.split(' - ')
      // Malformed headings are reported by checkRawHeadings.
      if (!version || !date || !VERSION.test(version) || !isValidDate(date)) continue
      if (releases.some(r => r.version === version)) {
        issues.push(`${pkg}: release ${version} appears twice`)
        continue
      }
      release = { pkg, version, date, sections: [], notes: [], compareUrl: links.get(version.toLowerCase()) }
      releases.push(release)
      continue
    }

    if (tag === 'h3') {
      const text = nodeText(node).trim()
      const type = CHANGE_TYPES.find(t => t === text)
      // Checked under [Unreleased] too, so a typo fails before the release.
      if (!type && (release || inUnreleased)) {
        issues.push(`${pkg} ${release?.version ?? 'Unreleased'}: section "${text}" is not one of ${CHANGE_TYPES.join(', ')}`)
      }
      if (!release || !type) {
        section = undefined
        continue
      }
      // A file may repeat a section within one release; render it once.
      section = release.sections.find(s => s.type === type)
      if (!section) {
        section = { type, nodes: [] }
        release.sections.push(section)
      }
      continue
    }

    if (!release) continue

    if (tag === 'h1') {
      issues.push(`${pkg} ${release.version}: unexpected top-level heading "${nodeText(node).trim()}"`)
      continue
    }

    if (section) section.nodes.push(node)
    else release.notes.push(node)
  }

  // A setext heading (underlined with ---) parses as h2 but has no `## ` line.
  const rawCount = checkRawHeadings(pkg, rawbody, issues)
  if (rawCount !== headingCount) {
    issues.push(`${pkg}: ${headingCount} level-2 headings parsed but ${rawCount} "## " lines found; use "## " headings only`)
  }

  for (const r of releases) {
    // List items count one by one, so a real entry after "No changes" is caught.
    const items = r.notes.flatMap(n => tagOf(n) === 'ul' ? (n as [string, Record<string, unknown>, ...MinimarkNode[]]).slice(2) : [n])
      .map(n => nodeText(n).trim())
      .filter(Boolean)
    if (items.length > 1 || (items.length === 1 && !NO_CHANGES.test(items[0]!))) {
      issues.push(`${pkg} ${r.version}: entries outside a "###" section`)
    }
    r.sections.sort((a, b) => CHANGE_TYPES.indexOf(a.type) - CHANGE_TYPES.indexOf(b.type))
  }
  return { releases, issues }
}

// Newest first. A pre-release sorts below its release; pre-release identifiers
// compare numerically where they are numbers (rc.10 after rc.2).
export function compareVersionsDesc(a: string, b: string): number {
  const parse = (v: string) => {
    const dash = v.indexOf('-')
    const core = dash === -1 ? v : v.slice(0, dash)
    return { parts: core.split('.').map(Number), pre: dash === -1 ? undefined : v.slice(dash + 1) }
  }
  const pa = parse(a)
  const pb = parse(b)
  for (let i = 0; i < 3; i++) {
    const diff = (pb.parts[i] ?? 0) - (pa.parts[i] ?? 0)
    if (diff !== 0) return diff
  }
  if (pa.pre === pb.pre) return 0
  if (pa.pre === undefined) return -1
  if (pb.pre === undefined) return 1
  return pb.pre.localeCompare(pa.pre, 'en', { numeric: true })
}

// One card of the page: either a version released in lockstep by several
// packages, or a single package release.
export interface ReleaseCard {
  id: string
  version: string
  // Set for a single package release; a lockstep card shows one label per package.
  pkg?: string
  date: string
  compareUrl?: string
  packages: PackageRelease[]
}

// Anchor ids: `v1-4-1` for a lockstep version, `overlay-0-4-0` for a package.
export function cardId(version: string, pkg?: string): string {
  const prefix = pkg ? pkg.replace(/^qora_devtools_/, '').replace(/^qora_/, '') : 'v'
  return `${prefix}-${version.replaceAll('.', '-')}`.replace(/^v-/, 'v')
}

function hasContent(r: PackageRelease): boolean {
  return r.sections.length > 0
}

function singleCard(r: PackageRelease): ReleaseCard {
  return { id: cardId(r.version, r.pkg), version: r.version, pkg: r.pkg, date: r.date, compareUrl: r.compareUrl, packages: [r] }
}

// Packages with their own versions, merged into one timeline: newest date
// first, then in the order the changelogs are given.
export function mergeByDate(changelogs: PackageRelease[][]): ReleaseCard[] {
  const order = new Map<string, number>()
  changelogs.forEach((releases, index) => releases.forEach(r => order.set(r.pkg, index)))
  return changelogs
    .flat()
    .filter(hasContent)
    .sort((a, b) => b.date.localeCompare(a.date)
      || order.get(a.pkg)! - order.get(b.pkg)!
      || compareVersionsDesc(a.version, b.version))
    .map(singleCard)
}

// Packages released in lockstep from `since` on: one card per version, the
// packages in the order given, the first one (qora) setting the date and the
// compare link. Older releases were not in lockstep and get a card each.
// A release with no section ("No changes in this package") adds no card.
export function groupByVersion(changelogs: PackageRelease[][], since: string): ReleaseCard[] {
  const isLockstep = (v: string) => compareVersionsDesc(v, since) <= 0
  const groups = new Map<string, ReleaseCard>()
  for (const releases of changelogs) {
    for (const r of releases) {
      if (!hasContent(r) || !isLockstep(r.version)) continue
      let group = groups.get(r.version)
      if (!group) {
        group = { id: cardId(r.version), version: r.version, date: r.date, compareUrl: r.compareUrl, packages: [] }
        groups.set(r.version, group)
      }
      group.compareUrl ??= r.compareUrl
      group.packages.push(r)
    }
  }
  const lockstep = [...groups.values()].sort((a, b) => compareVersionsDesc(a.version, b.version))
  // Most tags before the lockstep were never pushed, so their compare links
  // lead nowhere; those cards link to the source file instead.
  const before = mergeByDate(changelogs.map(releases => releases.filter(r => !isLockstep(r.version))))
    .map(card => ({ ...card, compareUrl: undefined }))
  return [...lockstep, ...before]
}
