// Playwright config for E2E testing
// Update 'baseURL' to your Cloudflare Pages deployment URL
// Example: 'https://linglong-test.pages.dev'

/** @type {import('@playwright/test').PlaywrightTestConfig} */
const config = {
  use: {
    baseURL: process.env.CLOUDFLARE_BASE_URL || 'https://linglong-test.pages.dev',
    headless: true,
    viewport: { width: 1280, height: 720 },
  },
  testDir: './tests',
};

module.exports = config;
