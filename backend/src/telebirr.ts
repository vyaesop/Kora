import crypto from 'crypto';

export type TelebirrConfig = {
  baseUrl: string;
  webBaseUrl: string;
  fabricAppId: string;
  appSecret: string;
  merchantAppId: string;
  merchantCode: string;
  privateKey: string;
  notifyUrl: string;
  redirectUrl?: string;
};

export type TelebirrCheckoutResult = {
  merchOrderId: string;
  prepayId: string;
  rawRequest: string;
  checkoutUrl: string;
  providerPayload: unknown;
};

const excludedFields = new Set([
  'sign',
  'sign_type',
  'header',
  'refund_info',
  'openType',
  'raw_request',
  'biz_content',
]);

export const hasTelebirrConfig = (config: Partial<TelebirrConfig>) =>
  Boolean(
    config.baseUrl &&
      config.webBaseUrl &&
      config.fabricAppId &&
      config.appSecret &&
      config.merchantAppId &&
      config.merchantCode &&
      config.privateKey &&
      config.notifyUrl,
  );

export const createTelebirrNonce = () => {
  const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const bytes = crypto.randomBytes(32);
  return Array.from(bytes, (byte) => chars[byte % chars.length]).join('');
};

export const createTelebirrTimestamp = () =>
  Math.floor(Date.now() / 1000).toString();

const flattenSignFields = (payload: Record<string, unknown>) => {
  const entries = new Map<string, string>();

  for (const [key, value] of Object.entries(payload)) {
    if (excludedFields.has(key) || value == null) continue;
    if (key === 'biz_content' && value && typeof value === 'object') {
      for (const [bizKey, bizValue] of Object.entries(
        value as Record<string, unknown>,
      )) {
        if (excludedFields.has(bizKey) || bizValue == null) continue;
        if (typeof bizValue === 'object') {
          entries.set(bizKey, JSON.stringify(bizValue));
        } else {
          entries.set(bizKey, String(bizValue));
        }
      }
      continue;
    }
    entries.set(key, String(value));
  }

  return [...entries.entries()].sort(([a], [b]) => a.localeCompare(b));
};

export const signTelebirrPayload = (
  payload: Record<string, unknown>,
  privateKey: string,
) => {
  const source = flattenSignFields(payload)
    .map(([key, value]) => `${key}=${value}`)
    .join('&');

  return crypto
    .sign('sha256', Buffer.from(source, 'utf8'), {
      key: privateKey,
      padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
      saltLength: crypto.constants.RSA_PSS_SALTLEN_DIGEST,
    })
    .toString('base64');
};

const buildRawRequest = ({
  merchantAppId,
  merchantCode,
  prepayId,
  privateKey,
}: {
  merchantAppId: string;
  merchantCode: string;
  prepayId: string;
  privateKey: string;
}) => {
  const base = {
    appid: merchantAppId,
    merch_code: merchantCode,
    nonce_str: createTelebirrNonce(),
    prepay_id: prepayId,
    timestamp: createTelebirrTimestamp(),
  };
  const sign = signTelebirrPayload(base, privateKey);
  return [
    `appid=${base.appid}`,
    `merch_code=${base.merch_code}`,
    `nonce_str=${base.nonce_str}`,
    `prepay_id=${base.prepay_id}`,
    `timestamp=${base.timestamp}`,
    `sign=${encodeURIComponent(sign)}`,
    'sign_type=SHA256WithRSA',
  ].join('&');
};

const applyFabricToken = async (config: TelebirrConfig) => {
  const res = await fetch(`${config.baseUrl}/payment/v1/token`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'X-APP-Key': config.fabricAppId,
    },
    body: JSON.stringify({ appSecret: config.appSecret }),
  });

  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(
      `Telebirr fabric token request failed: ${res.status} ${JSON.stringify(payload)}`,
    );
  }

  const token = String((payload as { token?: unknown }).token ?? '').trim();
  if (!token) {
    throw new Error('Telebirr fabric token response did not include a token.');
  }
  return token;
};

export const createTelebirrWebCheckout = async ({
  config,
  title,
  amount,
  merchOrderId,
  metadata,
}: {
  config: TelebirrConfig;
  title: string;
  amount: number;
  merchOrderId: string;
  metadata?: Record<string, unknown>;
}): Promise<TelebirrCheckoutResult> => {
  const fabricToken = await applyFabricToken(config);
  const requestPayload: Record<string, unknown> = {
    timestamp: createTelebirrTimestamp(),
    nonce_str: createTelebirrNonce(),
    method: 'payment.preorder',
    version: '1.0',
    biz_content: {
      notify_url: config.notifyUrl,
      redirect_url: config.redirectUrl,
      appid: config.merchantAppId,
      merch_code: config.merchantCode,
      merch_order_id: merchOrderId,
      trade_type: 'Checkout',
      title,
      total_amount: amount.toFixed(2),
      trans_currency: 'ETB',
      timeout_express: '120m',
      ...metadata,
    },
  };

  requestPayload.sign = signTelebirrPayload(requestPayload, config.privateKey);
  requestPayload.sign_type = 'SHA256WithRSA';

  const res = await fetch(`${config.baseUrl}/payment/v1/merchant/preOrder`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'X-APP-Key': config.fabricAppId,
      Authorization: fabricToken,
    },
    body: JSON.stringify(requestPayload),
  });

  const payload = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(
      `Telebirr preOrder failed: ${res.status} ${JSON.stringify(payload)}`,
    );
  }

  const providerPayload = payload as {
    biz_content?: { prepay_id?: unknown };
  };
  const prepayId = String(providerPayload.biz_content?.prepay_id ?? '').trim();
  if (!prepayId) {
    throw new Error(
      `Telebirr preOrder response did not include a prepay_id: ${JSON.stringify(payload)}`,
    );
  }

  const rawRequest = buildRawRequest({
    merchantAppId: config.merchantAppId,
    merchantCode: config.merchantCode,
    prepayId,
    privateKey: config.privateKey,
  });

  return {
    merchOrderId,
    prepayId,
    rawRequest,
    checkoutUrl: `${config.webBaseUrl}${rawRequest}&version=1.0&trade_type=Checkout`,
    providerPayload: payload,
  };
};
