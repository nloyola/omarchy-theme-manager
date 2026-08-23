const stringValue = (value) => String(value || "")
const objectValue = (value) => (value && typeof value === "object" ? value : {})
const arrayValue = (value) => (Array.isArray(value) ? value : [])

const plainTextValue = (value, maximumLength = 240) =>
  stringValue(value)
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/[<>&]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maximumLength)

const safePreviewUrl = (value) => {
  const url = stringValue(value).trim()
  const rawGitHubUrl =
    /^https:\/\/raw\.githubusercontent\.com\/[a-z0-9_.-]+\/[a-z0-9_.-]+\/[^/?#]+\/[^\s?#]+(?:\?[^\s#]*)?$/i
  const githubAttachmentUrl = /^https:\/\/github\.com\/user-attachments\/assets\/[0-9a-f-]{36}$/i
  return rawGitHubUrl.test(url) || githubAttachmentUrl.test(url) ? url : ""
}

const normalizeRepositoryUrl = (url) => {
  const normalized = stringValue(url)
    .trim()
    .replace(/^git@github\.com:/i, "https://github.com/")
    .replace(/^git:\/\/github\.com\//i, "https://github.com/")
    .replace(/^http:\/\/github\.com\//i, "https://github.com/")
    .replace(/[?#].*$/, "")
    .replace(/\/+$/, "")
    .replace(/\.git$/i, "")

  const match = normalized.match(/^https:\/\/github\.com\/([^/]+)\/([^/]+)$/i)
  return match ? `https://github.com/${match[1].toLowerCase()}/${match[2].toLowerCase()}` : ""
}

const repositoryName = (url) => {
  const normalized = normalizeRepositoryUrl(url)
  return normalized ? normalized.split("/").pop() : ""
}

const installSlugForRepositoryUrl = (url) =>
  repositoryName(url)
    .replace(/^omarchy-/i, "")
    .replace(/-theme$/i, "")
    .toLowerCase()

const isSafeThemeSlug = (slug) => /^[a-z0-9][a-z0-9._-]*$/.test(stringValue(slug))

const parsedArray = (value) => {
  if (Array.isArray(value)) return value
  if (!value) return []

  try {
    const parsed = JSON.parse(String(value))
    return Array.isArray(parsed) ? parsed : []
  } catch (_error) {
    return []
  }
}

const repositoryKeyMap = (values) =>
  arrayValue(values).reduce((repositories, url) => {
    const key = normalizeRepositoryUrl(url)
    if (key) repositories[key] = true
    return repositories
  }, {})

const displayStatus = ({ installed, stockConflict }) => {
  if (installed) return "Installed"
  if (stockConflict) return "Conflicts with stock theme"
  return "Install"
}

const catalogRows = (payload, inventory = {}) => {
  const data = objectValue(payload)
  const installedThemes = objectValue(inventory.installedThemes)
  const stockThemes = objectValue(inventory.stockThemes)
  const installedRepositories = repositoryKeyMap(inventory.installedRepositories)
  const officialRepositories = repositoryKeyMap(data.officialRepositories)
  const rowsByRepository = {}

  for (const entry of arrayValue(data.themes)) {
    const repositoryUrl = normalizeRepositoryUrl(entry.repositoryUrl || entry.github_url)
    const installSlug = installSlugForRepositoryUrl(repositoryUrl)
    if (!repositoryUrl || !isSafeThemeSlug(installSlug)) continue

    const installed =
      installedThemes[installSlug] === true || installedRepositories[repositoryUrl] === true
    const stockConflict = stockThemes[installSlug] === true
    const official = officialRepositories[repositoryUrl] === true
    const warnings = parsedArray(entry.securityWarnings || entry.security_warnings)
      .map((warning) => plainTextValue(warning, 180))
      .filter(Boolean)
    const apps = parsedArray(entry.apps || entry.apps_json)
      .map((app) => plainTextValue(app, 80))
      .filter(Boolean)
    const stars = Number(entry.stars) || 0
    const existing = rowsByRepository[repositoryUrl]

    if (existing) {
      existing.official = existing.official || official
      existing.stars = Math.max(existing.stars, stars)
      continue
    }

    const name = plainTextValue(entry.name || installSlug, 120)
    const owner = plainTextValue(entry.owner || entry.github_owner, 80)
    const description = plainTextValue(entry.description, 500)
    const previewUrl = safePreviewUrl(entry.previewUrl || entry.preview_url)

    rowsByRepository[repositoryUrl] = {
      filePath: repositoryUrl,
      fileName: `${installSlug}.webp`,
      thumbnailPath: previewUrl,
      displayName: name,
      installSlug,
      repositoryUrl,
      owner,
      description,
      stars,
      apps,
      warnings,
      official,
      installed,
      stockConflict,
      canInstall: !installed && !stockConflict,
      status: displayStatus({ installed, stockConflict }),
      searchText: [name, owner, description, installSlug, repositoryUrl, apps.join(" ")]
        .join(" ")
        .toLowerCase()
    }
  }

  return Object.keys(rowsByRepository)
    .map((key) => rowsByRepository[key])
    .sort((left, right) => {
      if (left.canInstall !== right.canInstall) return left.canInstall ? -1 : 1
      if (left.official !== right.official) return left.official ? -1 : 1
      if (left.stars !== right.stars) return right.stars - left.stars
      return left.displayName.localeCompare(right.displayName)
    })
}

const installConfirmationMessage = (entry) => {
  const row = objectValue(entry)
  if (!row.canInstall) return ""

  const origin = row.owner ? `@${row.owner}` : "its GitHub repository"
  const trust = row.official ? " Officially listed by Omarchy." : ""
  const warnings = arrayValue(row.warnings).slice(0, 3)
  const warning =
    warnings.length > 0
      ? ` Catalog note${warnings.length === 1 ? "" : "s"}: ${warnings.join("; ")}.`
      : ""

  return `Install ${row.displayName} from ${origin}? It will be cloned and applied immediately.${trust}${warning}`
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizeRepositoryUrl,
    repositoryName,
    installSlugForRepositoryUrl,
    isSafeThemeSlug,
    plainTextValue,
    safePreviewUrl,
    parsedArray,
    catalogRows,
    installConfirmationMessage
  }
}
