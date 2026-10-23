import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12;
const VERSION = 'v1';

/** Lê a chave de 32 bytes (base64) de `CONNECTOR_ENCRYPTION_KEY`. A chave nunca fica no banco. */
export function loadEncryptionKey(raw = process.env.CONNECTOR_ENCRYPTION_KEY): Buffer {
  if (!raw) throw new Error('CONNECTOR_ENCRYPTION_KEY não definida');
  const key = Buffer.from(raw, 'base64');
  if (key.length !== 32) throw new Error('CONNECTOR_ENCRYPTION_KEY deve ter 32 bytes em base64');
  return key;
}

/** Criptografa com AES-256-GCM. Formato: `v1.<iv>.<tag>.<ciphertext>` (base64url). */
export function encryptSecret(plaintext: string, key: Buffer): string {
  const iv = randomBytes(IV_BYTES);
  const cipher = createCipheriv(ALGORITHM, key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return [VERSION, iv, tag, ciphertext]
    .map((p) => (typeof p === 'string' ? p : p.toString('base64url')))
    .join('.');
}

export function decryptSecret(payload: string, key: Buffer): string {
  const [version, iv, tag, ciphertext] = payload.split('.');
  if (version !== VERSION || !iv || !tag || ciphertext === undefined) {
    throw new Error('Segredo criptografado em formato inválido');
  }
  const decipher = createDecipheriv(ALGORITHM, key, Buffer.from(iv, 'base64url'));
  decipher.setAuthTag(Buffer.from(tag, 'base64url'));
  return Buffer.concat([
    decipher.update(Buffer.from(ciphertext, 'base64url')),
    decipher.final(),
  ]).toString('utf8');
}
