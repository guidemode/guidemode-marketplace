#!/usr/bin/env node
// GuideMode OAuth Login Script
// Opens browser for GitHub OAuth via /auth/desktop, captures API key via localhost callback.
// No npm dependencies - uses only Node.js built-in modules.

import { createServer } from 'node:http'
import { readFileSync, writeFileSync, mkdirSync, chmodSync } from 'node:fs'
import { exec } from 'node:child_process'
import { homedir, platform } from 'node:os'
import { join } from 'node:path'
import { URL } from 'node:url'

const CONFIG_DIR = join(homedir(), '.guidemode')
const CONFIG_FILE = join(CONFIG_DIR, 'config.json')
const DEFAULT_SERVER = 'https://app.guidemode.dev'
const TIMEOUT_MS = 5 * 60 * 1000 // 5 minutes

// Parse args
const args = process.argv.slice(2)
const serverUrl = args.find(a => a.startsWith('--server='))?.split('=')[1] || DEFAULT_SERVER

function openBrowser(url) {
  const cmd =
    platform() === 'darwin'
      ? `open "${url}"`
      : platform() === 'win32'
        ? `start "" "${url}"`
        : `xdg-open "${url}"`
  exec(cmd, err => {
    if (err) {
      console.error(`\nCould not open browser automatically.`)
      console.error(`Please open this URL manually:\n  ${url}\n`)
    }
  })
}

async function findPort() {
  // Try ports 8765-8770 (same range as desktop app, allowed by server's validateCliRedirectUri)
  for (let port = 8765; port <= 8770; port++) {
    try {
      await new Promise((resolve, reject) => {
        const server = createServer()
        server.once('error', reject)
        server.listen(port, '127.0.0.1', () => {
          server.close(() => resolve(port))
        })
      })
      return port
    } catch {
      continue
    }
  }
  throw new Error('No available port in range 8765-8770')
}

async function verifyCredentials(serverUrl, apiKey) {
  const res = await fetch(`${serverUrl}/auth/session`, {
    headers: { Authorization: `Bearer ${apiKey}` },
  })
  if (!res.ok) {
    throw new Error(`Credential verification failed: HTTP ${res.status}`)
  }
  return res.json()
}

function saveConfig(config) {
  mkdirSync(CONFIG_DIR, { recursive: true, mode: 0o700 })
  writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2), { mode: 0o600 })
}

async function main() {
  console.log('GuideMode Login')
  console.log('===============\n')

  const port = await findPort()
  const redirectUri = `http://127.0.0.1:${port}/callback`

  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      server.close()
      reject(new Error('Login timed out after 5 minutes'))
    }, TIMEOUT_MS)

    const server = createServer(async (req, res) => {
      const url = new URL(req.url, `http://127.0.0.1:${port}`)

      if (url.pathname === '/callback') {
        const key = url.searchParams.get('key')
        const tenantId = url.searchParams.get('tenant_id')
        const tenantName = url.searchParams.get('tenant_name')

        if (!key || !tenantId) {
          res.writeHead(400, { 'Content-Type': 'text/html' })
          res.end(errorPage('Missing key or tenant_id in callback'))
          clearTimeout(timeout)
          server.close()
          reject(new Error('Missing key or tenant_id in callback'))
          return
        }

        try {
          // Verify credentials
          const session = await verifyCredentials(serverUrl, key)

          const config = {
            apiKey: key,
            serverUrl: serverUrl,
            tenantId: tenantId,
            tenantName: tenantName || '',
            username: session.user?.username || '',
            name: session.user?.name || '',
            avatarUrl: session.user?.avatarUrl || '',
          }

          saveConfig(config)

          res.writeHead(200, { 'Content-Type': 'text/html' })
          res.end(successPage(config))

          clearTimeout(timeout)
          server.close()

          console.log(`Logged in as ${config.username || config.name} to ${config.tenantName}`)
          console.log(`Config saved to ${CONFIG_FILE}\n`)
          resolve()
        } catch (err) {
          res.writeHead(500, { 'Content-Type': 'text/html' })
          res.end(errorPage(`Verification failed: ${err.message}`))
          clearTimeout(timeout)
          server.close()
          reject(err)
        }
      } else {
        res.writeHead(404)
        res.end('Not found')
      }
    })

    server.listen(port, '127.0.0.1', () => {
      const authUrl = `${serverUrl}/auth/desktop?redirect_uri=${encodeURIComponent(redirectUri)}`
      console.log(`Opening browser for authentication...\n`)
      console.log(`If the browser doesn't open, visit:\n  ${authUrl}\n`)
      console.log('Waiting for login...\n')
      openBrowser(authUrl)
    })
  })
}

function successPage(config) {
  return `<!DOCTYPE html>
<html>
<head>
  <title>GuideMode - Login Successful</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; margin: 0; padding: 40px 20px;
           background: #f8fafc; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
    .container { background: white; padding: 40px; border-radius: 12px;
                 box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); text-align: center; max-width: 400px; }
    h1 { color: #059669; font-size: 24px; }
    p { color: #6b7280; line-height: 1.5; }
    .info { background: #f0fdf4; padding: 16px; border-radius: 8px; margin: 16px 0; }
    .info strong { color: #166534; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Login Successful</h1>
    <div class="info">
      <p>Logged in as <strong>${escapeHtml(config.username || config.name)}</strong></p>
      <p>Team: <strong>${escapeHtml(config.tenantName)}</strong></p>
    </div>
    <p>You can close this tab and return to your terminal.</p>
    <p>Claude Code sessions will now sync to GuideMode automatically.</p>
  </div>
</body>
</html>`
}

function errorPage(message) {
  return `<!DOCTYPE html>
<html>
<head>
  <title>GuideMode - Login Failed</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; margin: 0; padding: 40px 20px;
           background: #f8fafc; min-height: 100vh; display: flex; align-items: center; justify-content: center; }
    .container { background: white; padding: 40px; border-radius: 12px;
                 box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); text-align: center; max-width: 400px; }
    h1 { color: #dc2626; font-size: 24px; }
    p { color: #6b7280; line-height: 1.5; }
    .error { background: #fef2f2; padding: 16px; border-radius: 8px; color: #991b1b; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Login Failed</h1>
    <div class="error"><p>${escapeHtml(message)}</p></div>
    <p>Please try again from the terminal.</p>
  </div>
</body>
</html>`
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

main().catch(err => {
  console.error(`\nLogin failed: ${err.message}`)
  process.exit(1)
})
