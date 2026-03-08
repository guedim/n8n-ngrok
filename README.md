# n8n con Docker y ngrok

Stack de automatización con n8n, PostgreSQL con pgvector, Redis y ngrok.

## Servicios

| Servicio | Imagen | Puerto | Descripción |
| -------- | ------ | ------ | ----------- |
| **n8n** | `docker.n8n.io/n8nio/n8n` | `5678` | Motor de automatización y workflows (UI + webhook intake) |
| **n8n-worker** | `docker.n8n.io/n8nio/n8n` | — | 3 workers en paralelo que procesan los jobs encolados en Redis |
| **PostgreSQL** | `pgvector/pgvector:pg16` | `5432` | Base de datos principal con soporte de vectores (pgvector) para RAG |
| **Redis** | `redis/redis-stack` | `6379` / `8001` | Cola de ejecuciones (Bull queue) + Redis Insight UI |
| **ngrok** | `ngrok/ngrok` | `4040` | Túnel HTTPS para exponer n8n públicamente con dominio estático |
| **Adminer** | `adminer` | `8080` | Cliente web para administrar PostgreSQL |

## Persistencia

Los datos persisten en volúmenes Docker:

| Volumen | Contenido |
| ------- | --------- |
| `postgres_data` | Base de datos PostgreSQL (workflows, credenciales, ejecuciones) |
| `n8n_data` | Configuración y datos de n8n |
| `n8n_custom_nodes` | Nodos personalizados instalados |
| `n8n_workflows` | Workflows exportados |
| `redis_data` | Datos de Redis |

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
| `POSTGRES_DB` | Nombre de la base de datos |
| `POSTGRES_USER` | Usuario de PostgreSQL (sin guiones ni caracteres especiales) |
| `POSTGRES_PASSWORD` | Contraseña de PostgreSQL |
| `EXECUTIONS_MODE` | Modo de ejecución — `queue` para usar Redis + worker |
| `QUEUE_BULL_REDIS_HOST` | Hostname del contenedor Redis (default: `redis`) |
| `QUEUE_BULL_REDIS_PORT` | Puerto de Redis (default: `6379`) |
| `N8N_PROXY_HOPS` | Número de proxies de confianza delante de n8n — `1` cuando se usa ngrok |
| `OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS` | Envía ejecuciones manuales al worker en lugar del proceso principal |
| `TZ` / `TIMEZONE` / `GENERIC_TIMEZONE` | Zona horaria (ej: `America/Bogota`) |

## Iniciar

```bash
docker compose up -d
```

Verificar que está corriendo:

```bash
docker compose ps
```

- n8n local: <http://localhost:5678>
- n8n remoto: `https://<NGROK_DOMAIN>`
- Panel ngrok: <http://localhost:4040>
- Adminer (DB): <http://localhost:8080>
- Redis Insight: <http://localhost:8001>

## Detener

```bash
docker compose down
```

## Ver logs

```bash
# Todos los servicios
docker compose logs -f

# Solo n8n (UI principal)
docker compose logs -f n8n

# Solo el worker
docker compose logs -f n8n-worker

# Solo ngrok
docker compose logs -f ngrok

# Solo postgres
docker compose logs -f postgres
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

## Eliminar datos y reiniciar desde cero

> **Advertencia:** esto borra todos los datos persistidos.

```bash
docker compose down
docker volume rm docker_postgres_data docker_n8n_data docker_n8n_custom_nodes docker_n8n_workflows docker_redis_data
docker compose up -d
```

Para borrar solo la base de datos (útil si cambias `POSTGRES_USER`):

```bash
docker compose down
docker volume rm docker_postgres_data
docker compose up -d
```

## Arquitectura de ejecución

n8n corre en modo cola (`EXECUTIONS_MODE=queue`):

```text
ngrok → n8n (encola job en Redis) → n8n-worker (ejecuta job) → guarda resultado en PostgreSQL
```

- El proceso **n8n** gestiona la UI, recibe webhooks y encola las ejecuciones en Redis.
- Los **3 procesos n8n-worker** leen la cola en paralelo y ejecutan los workflows. Redis distribuye los jobs automáticamente entre ellos.
- **PostgreSQL** almacena workflows, credenciales e historial de ejecuciones de forma persistente.
- **Redis** solo mantiene la cola temporal de jobs.

## Notas

- El dominio estático de ngrok no cambia entre reinicios siempre que se use el flag `--url`.
- `N8N_PROXY_HOPS=1` es necesario porque ngrok agrega el header `X-Forwarded-For`.
- El script `init-scripts/init-pgvector.sh` se ejecuta automáticamente la primera vez que se crea la base de datos, habilitando pgvector y creando las tablas de embeddings para RAG.
- Los scripts de init **no se vuelven a ejecutar** si el volumen `postgres_data` ya existe.
- Si cambias `POSTGRES_USER`, debes eliminar el volumen `postgres_data` y reiniciar.
