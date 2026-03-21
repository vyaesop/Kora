import { cp, mkdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, '..');
const distDir = path.join(projectRoot, 'dist');

const configuredApiBase = (process.env.KORA_ADMIN_API_BASE_URL || '').trim();
const escapedApiBase = JSON.stringify(configuredApiBase);

await rm(distDir, { recursive: true, force: true });
await mkdir(distDir, { recursive: true });

for (const fileName of ['index.html', 'styles.css', 'app.js']) {
  await cp(path.join(projectRoot, fileName), path.join(distDir, fileName));
}

await writeFile(
  path.join(distDir, 'config.js'),
  `window.KORA_ADMIN_CONFIG = { apiBase: ${escapedApiBase} };\n`,
  'utf8',
);
