const ALLOWED_TYPES = new Set(['Artiste', 'Club / lieu', 'Événement', 'Partenaire']);
const DEFAULT_ORIGINS = ['https://3h33agency.fr', 'https://www.3h33agency.fr'];

function respond(res, status, body) {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  return res.status(status).json(body);
}

function getPayload(req) {
  if (req.body && typeof req.body === 'object' && !Buffer.isBuffer(req.body)) {
    return req.body;
  }

  const raw = Buffer.isBuffer(req.body) ? req.body.toString('utf8') : req.body;
  return JSON.parse(raw || '{}');
}

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return respond(res, 405, { error: 'Méthode non autorisée.' });
  }

  const allowedOrigins = (process.env.ALLOWED_ORIGINS || DEFAULT_ORIGINS.join(','))
    .split(',')
    .map(function(origin) { return origin.trim().replace(/\/+$/, ''); })
    .filter(Boolean);
  let requestOrigin = '';

  try {
    requestOrigin = new URL(req.headers.origin || '').origin;
  } catch {
    return respond(res, 403, { error: 'Origine de la requête non autorisée.' });
  }

  if (!allowedOrigins.includes(requestOrigin)) {
    return respond(res, 403, { error: 'Origine de la requête non autorisée.' });
  }

  let payload;
  try {
    payload = getPayload(req);
  } catch {
    return respond(res, 400, { error: 'Le formulaire est invalide.' });
  }

  if (cleanString(payload.website)) {
    return respond(res, 200, { ok: true });
  }

  const name = cleanString(payload.name);
  const type = cleanString(payload.type);
  const email = cleanString(payload.email);
  const message = cleanString(payload.message);

  if (
    name.length < 1 || name.length > 120 ||
    !ALLOWED_TYPES.has(type) ||
    email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
    message.length < 1 || message.length > 5000
  ) {
    return respond(res, 400, { error: 'Vérifiez les champs du formulaire.' });
  }

  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.RESEND_FROM_EMAIL;
  const to = process.env.RESEND_TO_EMAIL || 'contact@n8life.fr';

  if (!apiKey || !from) {
    return respond(res, 503, { error: 'Le service d’envoi n’est pas encore configuré.' });
  }

  let resendResponse;
  try {
    resendResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + apiKey,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        from: from,
        to: [to],
        reply_to: email,
        subject: 'Demande 3H33 — ' + type,
        text: [
          'Nom : ' + name,
          'E-mail : ' + email,
          'Type de demande : ' + type,
          '',
          'Message :',
          message
        ].join('\n')
      })
    });
  } catch (error) {
    console.error('Resend request failed:', error.message);
    return respond(res, 502, { error: 'Le service d’envoi est momentanément indisponible.' });
  }

  if (!resendResponse.ok) {
    console.error('Resend rejected the email request with status:', resendResponse.status);
    return respond(res, 502, { error: 'L’e-mail n’a pas pu être envoyé. Réessayez ou utilisez le lien e-mail.' });
  }

  return respond(res, 200, { ok: true });
};
