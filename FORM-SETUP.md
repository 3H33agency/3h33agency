# Configuration du formulaire de contact

Le formulaire utilise la fonction Vercel `api/contact.js` et l’API Resend. Il ne peut envoyer les demandes qu’après configuration des variables d’environnement dans Vercel.

## Variables d’environnement

Dans le projet Vercel `3h33-agency-v8`, ouvre **Settings → Environment Variables** et ajoute ces variables pour l’environnement **Production** :

| Nom | Valeur |
| --- | --- |
| `RESEND_API_KEY` | Clé API Resend, à conserver secrète |
| `RESEND_FROM_EMAIL` | Adresse expéditeur sur un domaine vérifié dans Resend, par exemple `3H33 <contact@domaine-verifie.fr>` |
| `RESEND_TO_EMAIL` | Adresse qui reçoit les demandes ; par défaut `contact@n8life.fr` |

Dans Resend, vérifie le domaine expéditeur et configure les enregistrements DNS demandés avant de compter sur l’envoi en production. Ne place jamais la clé API dans `index.html` et ne la partage pas dans un chat.

Pour tester une prévisualisation Vercel, ajoute également les variables à l’environnement **Preview**. L’endpoint autorise par défaut `https://3h33agency.fr` et `https://www.3h33agency.fr`. Une variable optionnelle `ALLOWED_ORIGINS` peut remplacer cette liste, avec des origines séparées par des virgules.

Après avoir ajouté ou modifié les variables, relance un déploiement Vercel afin que la fonction les récupère. Si l’envoi direct échoue ou n’est pas encore configuré, le formulaire affiche un lien de repli qui prépare le même message dans l’application e-mail du visiteur.
