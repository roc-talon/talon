// Manifest flow of the GitHub App "Talon Indexer" (R-PU25, G14).
// 1. Starts a server on 127.0.0.1 that serves a page with an auto-submit form to GitHub.
// 2. GitHub redirects to /done?code=...&state=... after the person clicks "Create GitHub App".
// 3. Converts the code with `gh api -X POST /app-manifests/<code>/conversions`.
// 4. Saves the keys outside the repo, mode 600. Never prints a secret.
import http from 'node:http'
import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { execFile } from 'node:child_process'

const ORG = 'roc-talon'
const outDir = process.env.TALON_INDEXER_DIR || path.join(os.homedir(), '.config', 'talon-indexer')
const state = crypto.randomBytes(16).toString('hex')
const wantedPort = Number(process.argv[2] || 0)

const esc = s => s.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;')

// The manifest. The choices are in README.md.
function manifest(port) {
  return {
    name: 'Talon Indexer',
    url: 'https://github.com/roc-talon/talon',
    // Placeholder: the Worker is not deployed. The hook is off (active: false) until slice 118.
    hook_attributes: { url: 'https://example.com/v1/webhooks/github', active: false },
    redirect_url: `http://127.0.0.1:${port}/done`,
    public: false,
    default_permissions: { metadata: 'read', contents: 'read' },
    // installation and installation_repositories are sent to every App, they are not in this list.
    default_events: ['release', 'repository'],
  }
}

function run(cmd, args) {
  return new Promise((resolve, reject) =>
    execFile(cmd, args, { maxBuffer: 1 << 24 }, (err, stdout, stderr) =>
      err ? reject(new Error(`${cmd} failed: ${String(stderr).trim().split('\n')[0]}`)) : resolve(stdout)))
}

function save(name, value) {
  fs.mkdirSync(outDir, { recursive: true, mode: 0o700 })
  fs.chmodSync(outDir, 0o700)
  const file = path.join(outDir, name)
  fs.writeFileSync(file, String(value).replace(/\n*$/, '\n'), { mode: 0o600 })
  fs.chmodSync(file, 0o600)
}

const page = (title, body) =>
  `<!doctype html><meta charset="utf-8"><title>${esc(title)}</title><body style="font-family:sans-serif;max-width:40em;margin:2em auto">${body}`

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1')
  const send = (code, html) => { res.writeHead(code, { 'content-type': 'text/html; charset=utf-8' }); res.end(html) }
  if (url.pathname === '/') {
    const port = server.address().port
    const action = `https://github.com/organizations/${ORG}/settings/apps/new?state=${state}`
    return send(200, page('Talon Indexer', `<p>Sending the manifest to GitHub...</p>
<form id="f" method="post" action="${esc(action)}">
<input type="hidden" name="manifest" value="${esc(JSON.stringify(manifest(port)))}">
<noscript><button>Send the manifest</button></noscript></form>
<script>document.getElementById('f').submit()</script>`))
  }
  if (url.pathname === '/done') {
    const code = url.searchParams.get('code') || ''
    if (url.searchParams.get('state') !== state || !/^[A-Za-z0-9]+$/.test(code)) return send(400, page('Error', '<p>Bad state or code.</p>'))
    try {
      const app = JSON.parse(await run('gh', ['api', '-X', 'POST', `/app-manifests/${code}/conversions`]))
      save('id', app.id)
      save('slug', app.slug)
      save('client_id', app.client_id)
      save('client_secret', app.client_secret)
      save('webhook_secret', app.webhook_secret)
      save('private-key.pem', app.pem)
      const install = `https://github.com/apps/${app.slug}/installations/new`
      console.log(`App created: id ${app.id}, slug ${app.slug}`)
      console.log(`Keys saved in ${outDir} (mode 600). Nothing secret is printed.`)
      console.log(`\nStep 2: open this URL, choose ${ORG}, then "Only select repositories", then ${ORG}/talon only:\n  ${install}\n`)
      console.log('Step 3: research/github-app-check/check.sh')
      send(200, page('Done', `<p>The App is created. Next step: <a href="${esc(install)}">install it on ${ORG}</a> (only ${ORG}/talon). You can close this tab.</p>`))
    } catch (e) {
      console.error(String(e.message))
      send(500, page('Error', '<p>The conversion failed. See the terminal.</p>'))
    }
    setTimeout(() => server.close(() => process.exit(process.exitCode || 0)), 200)
    return
  }
  send(404, page('Not found', '<p>Not found.</p>'))
})

server.listen(wantedPort, '127.0.0.1', () => {
  const port = server.address().port
  console.log(`Step 1: open this URL in the browser, then click "Create GitHub App":\n  http://127.0.0.1:${port}/\n`)
  console.log(`Keys will be saved in ${outDir}. Waiting for GitHub (Ctrl-C to stop)...`)
})
