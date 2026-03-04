# n8n con Docker y ngrok

## Requisitos

- Docker y Docker Compose instalados
- Cuenta en [ngrok.com](https://ngrok.com) con dominio estático y authtoken configurados

## Configuración inicial

Copia el archivo de ejemplo y edítalo con tus valores:

```bash
cp .env.example .env
```

Variables disponibles en `.env`:

| Variable | Descripción |
| -------- | ----------- |
| `NGROK_DOMAIN` | Tu dominio estático de ngrok (ej: `tu-subdominio.ngrok-free.app`) |
| `NGROK_AUTHTOKEN` | Tu authtoken de ngrok |
| `N8N_HOST` | Igual que `NGROK_DOMAIN` |
| `WEBHOOK_URL` | URL completa con https (ej: `https://tu-subdominio.ngrok-free.app/`) |
| `TZ` / `TIMEZONE` / `GENERIC_TIMEZONE` | Zona horaria (ej: `America/Bogota`) |

## Iniciar

```bash
docker compose up -d
```

Verificar que está corriendo:

```bash
docker compose ps
```

- Acceso local: <http://localhost:5678>
- Acceso remoto: `https://<NGROK_DOMAIN>`
- Panel ngrok: <http://localhost:4040>

## Detener

```bash
docker compose down
```

## Ver logs

```bash
# Todos los servicios
docker compose logs -f

# Solo n8n
docker compose logs -f n8n

# Solo ngrok
docker compose logs -f ngrok
```

## Conectar Gmail OAuth2

1. Ir a [Google Cloud Console](https://console.cloud.google.com/)
2. Crear un proyecto y habilitar la **Gmail API**
3. Ir a **APIs & Services > Credentials > Create Credentials > OAuth Client ID**
4. Tipo: **Web application**
5. En **Authorized redirect URIs** agregar:

   ```text
   https://<NGROK_DOMAIN>/rest/oauth2-credential/callback
   ```

6. Copiar **Client ID** y **Client Secret**
7. En n8n, crear credencial **Gmail OAuth2 API** y pegar los valores
8. Click en **Sign in with Google** y autorizar

## Agregar Chat Model de IA (Google Gemini)

1. Ir a [Google AI Studio](https://aistudio.google.com/apikey) y crear una API key
2. En tu workflow, agregar un nodo **AI Agent**
3. En el sub-nodo **Chat Model**, seleccionar **Google Gemini Chat Model**
4. Click en **Create New Credential** y pegar la API key

## Notas

- El dominio estático de ngrok no cambia entre reinicios siempre que se use el flag `--url`.
- ngrok y n8n se inician juntos con `docker compose up -d`.
