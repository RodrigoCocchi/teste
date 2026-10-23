import { expect, test } from '@playwright/test';

test.describe('escritório (modo demo local)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/?q=low');
  });

  test('renderiza a cena 3D e recebe eventos ao vivo', async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (e) => errors.push(e.message));
    await expect(page.getByText('Demo local')).toBeVisible();
    await expect(page.locator('canvas')).toBeVisible({ timeout: 20_000 });
    // O feed recebe eventos da simulação local.
    await expect(page.locator('[aria-live] li').first()).toBeVisible({ timeout: 20_000 });
    // Rótulos dos agentes aparecem sobre a cena.
    await expect(page.getByText('Suporte N1').first()).toBeVisible();
    expect(errors).toEqual([]);
  });

  test('abas de chamados e métricas mostram os dados do demo', async ({ page }) => {
    await page.getByRole('tab', { name: 'Chamados' }).click();
    await expect(page.getByRole('heading', { name: /Novos/ })).toBeVisible();
    await expect(page.getByText('Impressora do 2º andar não imprime')).toBeVisible();
    await page.getByRole('tab', { name: 'Métricas' }).click();
    await expect(page.getByText('Chamados abertos')).toBeVisible();
  });

  test('não tem rolagem horizontal', async ({ page }) => {
    await expect(page.locator('canvas')).toBeVisible({ timeout: 20_000 });
    const overflow = await page.evaluate(
      () => document.documentElement.scrollWidth - window.innerWidth,
    );
    expect(overflow).toBeLessThanOrEqual(0);
  });
});
