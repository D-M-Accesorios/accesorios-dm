# Quickstart — Backend para desarrollo frontend

Esta guía te permite levantar el backend completo en tu máquina local en menos de 5 minutos.

## Prerequisitos

| Herramienta | Versión mínima | Verificar |
|---|---|---|
| Docker Desktop | 4.x (Engine ≥ 26) | `docker --version` |
| Docker Compose | ≥ 2.24 (incluido en Docker Desktop) | `docker compose version` |
| Node.js | ≥ 18 | `node --version` |
| Git | cualquiera | `git --version` |

---

## Paso 1 — Clonar los repos

Todos los repos deben quedar **en la misma carpeta padre**. El nombre de la carpeta no importa.

```bash
mkdir app-accesorios-dm && cd app-accesorios-dm

git clone https://github.com/SergioLosadaDev/accesorios-dm-database
git clone https://github.com/SergioLosadaDev/accesorios-dm-api-gateway
git clone https://github.com/SergioLosadaDev/accesorios-dm-inventory-service
git clone https://github.com/SergioLosadaDev/dm-deployment
```

La estructura resultante debe verse así:

```
app-accesorios-dm/
├── accesorios-dm-database/
├── accesorios-dm-api-gateway/
├── accesorios-dm-inventory-service/
└── dm-deployment/
```

> **Importante:** si los repos quedan en carpetas distintas, el `docker-compose.yml` no podrá encontrar los paths relativos y fallará.

---

## Paso 2 — Configurar el entorno

```bash
cd dm-deployment
cp .env.dev.example .env
```

El archivo `.env` ya viene con todo configurado para desarrollo local, incluyendo la clave JWT. No necesitas cambiar nada para empezar.

---

## Paso 3 — Levantar el backend

```bash
# Solo los servicios de backend (recomendado para desarrollo frontend)
docker compose up -d postgres liquibase inventory-service api-gateway
```

La primera vez tarda más porque Docker descarga las imágenes base y compila los servicios. Espera a que todos estén `healthy`:

```bash
docker compose ps
```

Salida esperada cuando todo está listo:

```
NAME                        STATUS
accesorios-dm-postgres      running (healthy)
accesorios-dm-liquibase     exited (0)          ← normal, termina tras aplicar migraciones
accesorios-dm-inventory     running (healthy)
accesorios-dm-gateway       running (healthy)
```

> Spring Boot puede tardar **60-90 segundos** en arrancar. Si el gateway muestra `starting` espera un poco más.

---

## Paso 4 — Verificar que funciona

```bash
# Health del gateway (sin autenticación)
curl http://localhost:3000/health
# → {"status":"UP","timestamp":"..."}

# Health con estado de servicios dependientes
curl http://localhost:3000/health/services
```

---

## Paso 5 — Obtener un token JWT de prueba

El servicio de seguridad aún no existe. Usa el generador de tokens de desarrollo:

```bash
# Token como ADMIN (acceso total)
node scripts/generate-dev-token.js

# Token como VENDEDOR (puede registrar movimientos)
node scripts/generate-dev-token.js mi-vendedor VENDEDOR
```

El script imprime el token listo para copiar y pegar.

---

## Paso 6 — Probar la API

```bash
TOKEN=$(node scripts/generate-dev-token.js 2>/dev/null | grep "^ey")

# Listar categorías
curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/catalog/categories

# Listar productos con stock
curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/catalog/products

# Consultar stock de todos los productos
curl -H "Authorization: Bearer $TOKEN" http://localhost:3000/api/v1/inventory/stock
```

---

## Comandos útiles

```bash
# Ver logs en tiempo real
docker compose logs -f api-gateway
docker compose logs -f inventory-service

# Detener el stack (conserva la base de datos)
docker compose down

# Reset completo (borra la base de datos)
docker compose down -v

# Reconstruir un servicio tras cambios en el código
docker compose build inventory-service
docker compose up -d inventory-service
```

---

## Limitaciones conocidas

| Ruta | Estado | Motivo |
|---|---|---|
| `POST /api/v1/auth/*` | ❌ 502 | El servicio de seguridad no existe aún |
| `GET /api/v1/users/*` | ❌ 502 | Idem |
| `GET /api/v1/roles/*` | ❌ 502 | Idem |
| `GET /api/v1/catalog/*` | ✅ Funciona | |
| `GET /api/v1/inventory/*` | ✅ Funciona | |
| `POST /api/v1/inventory/movements` | ✅ Funciona | |

Cuando el servicio de seguridad esté listo, reemplaza `JWT_PUBLIC_KEY` en `.env` con la clave pública real y el login funcionará sin cambiar nada más.

---

## Troubleshooting

**`liquibase` sale con código distinto a 0**
```bash
docker compose logs liquibase
# Si el error es de conexión, postgres no estaba listo. Reinicia solo liquibase:
docker compose up liquibase
```

**`inventory-service` no pasa a `healthy`**
```bash
docker compose logs inventory-service | tail -30
# Si ves "Unable to acquire JDBC Connection", espera que liquibase termine primero
```

**`api-gateway` sale `unhealthy`**
```bash
docker compose logs api-gateway | tail -20
# Si ves "JWT_PUBLIC_KEY is empty", verifica que .env tiene la variable
```

**Puerto 5432 ocupado**
```bash
# Cambia el puerto en .env:
POSTGRES_PORT=5433
docker compose up -d
```
