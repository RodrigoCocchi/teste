import { randomBytes } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { decryptSecret, encryptSecret, loadEncryptionKey } from './crypto.js';

describe('crypto de credenciais', () => {
  const key = randomBytes(32);

  it('faz ida e volta e gera IV diferente a cada chamada', () => {
    const a = encryptSecret('token-secreto', key);
    const b = encryptSecret('token-secreto', key);
    expect(a).not.toBe(b);
    expect(decryptSecret(a, key)).toBe('token-secreto');
  });

  it('rejeita conteúdo adulterado e chave errada', () => {
    const enc = encryptSecret('x', key);
    const parts = enc.split('.');
    parts[3] = Buffer.from('y').toString('base64url');
    expect(() => decryptSecret(parts.join('.'), key)).toThrow();
    expect(() => decryptSecret(enc, randomBytes(32))).toThrow();
  });

  it('valida o tamanho da chave', () => {
    expect(() => loadEncryptionKey(Buffer.alloc(16).toString('base64'))).toThrow();
    expect(loadEncryptionKey(key.toString('base64'))).toHaveLength(32);
  });
});
