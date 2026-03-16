// Basic Playwright E2E test for Cloudflare deployment
const { test, expect } = require('@playwright/test');

test('homepage loads and shows title', async ({ page }) => {
  await page.goto('/');
  // Adjust selector/text as needed for your app
  await expect(page).toHaveTitle(/linglong/i);
  await expect(page.locator('body')).toContainText(['login', 'dashboard', 'person', 'athlete']);
});
