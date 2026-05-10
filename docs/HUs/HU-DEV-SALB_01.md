# HU-DEV-SALB_01 — Configuración base del proyecto NestJS (API Gateway)

| Campo              | Valor                                      |
|--------------------|--------------------------------------------|
| **ID**             | HU-DEV-SALB_01                             |
| **Servicio**       | API Gateway                                |
| **Repositorio**    | `accesorios-dm-api-gateway`                |
| **Prioridad**      | Crítica                                    |
| **Estado**         | Pendiente                                  |
| **ADRs**           | ADR-002, ADR-008                           |
| **Rama**           | `HU-DEV-SALB_01`                           |
| **Fecha**          | 2026-05-10                                 |

---

## Historia de Usuario

> **Como** equipo de desarrollo,
> **quiero** tener la estructura base del API Gateway configurada y lista,
> **para** tener un punto de partida consistente, mantenible y alineado con los
> estándares del proyecto antes de desarrollar cualquier funcionalidad.

---

## Criterios de Aceptación

- [ ] El proyecto NestJS está inicializado con Node.js 20 LTS y TypeScript.
- [ ] La estructura de módulos base está creada: `AppModule`, `AuthModule`, `ProxyModule`, `HealthModule`, `CommonModule`.
- [ ] El prefijo global de rutas es `/api/v1` configurado en `main.ts`.
- [ ] Existe un `Dockerfile` multi-stage (build + production) para el servicio.
- [ ] El servicio tiene entrada en `docker-compose.yml` del proyecto raíz con nombre de contenedor `api-gateway` y puerto `3000`.
- [ ] Todas las variables de entorno requeridas están documentadas en `.env.example` con descripción de cada una.
- [ ] El archivo `.env` está en `.gitignore`.
- [ ] El servidor arranca correctamente en el puerto `3000` con `npm run start:dev`.
- [ ] Existe un `README.md` del servicio con instrucciones de setup local.

---

## Variables de Entorno Requeridas

```
PORT=3000
NODE_ENV=development

# Servicios internos
SECURITY_SERVICE_URL=http://security-service:8081
INVENTORY_SERVICE_URL=http://inventory-service:8082

# JWT
JWT_PUBLIC_KEY=<RSA public key PEM>

# CORS
ALLOWED_ORIGINS=http://localhost:4200

# Rate Limiting
RATE_LIMIT_TTL=60
RATE_LIMIT_MAX=100
```

---

## Estructura de Módulos Propuesta

```
src/
├── app.module.ts
├── main.ts
├── common/
│   ├── filters/
│   │   └── http-exception.filter.ts      (HU-DEV-SALB_03)
│   ├── interceptors/
│   │   └── logging.interceptor.ts        (HU-DEV-SALB_04)
│   └── guards/
│       └── jwt-auth.guard.ts             (HU-DEV-SALB_05)
├── proxy/
│   └── proxy.module.ts                   (HU-DEV-SALB_07, 08)
└── health/
    └── health.module.ts                  (HU-DEV-SALB_09)
```

---

## Notas Técnicas

- Usar `@nestjs/config` para gestión centralizada de variables de entorno con validación al arranque (Joi o class-validator).
- El `ValidationPipe` global debe activarse con `whitelist: true` y `forbidNonWhitelisted: true`.
- El prefijo global `/api/v1` se define en `app.setGlobalPrefix('api/v1')` en `main.ts`.
- Deshabilitar la ruta `/` por defecto de NestJS para no exponer información del framework.

---

## Dependencias

| Tipo | HU / Artefacto | Descripción |
|---|---|---|
| Ninguna (primera HU) | — | Esta HU desbloquea todas las demás del Gateway |

---

## Desbloquea

`HU-DEV-SALB_02`, `HU-DEV-SALB_03`, `HU-DEV-SALB_04`, `HU-DEV-SALB_05`, `HU-DEV-SALB_06`, `HU-DEV-SALB_07`, `HU-DEV-SALB_08`, `HU-DEV-SALB_09`

---

## Definición de Done

- [ ] Código en rama `HU-DEV-SALB_01` revisado y aprobado por al menos 1 reviewer.
- [ ] El servicio levanta correctamente con `docker-compose up api-gateway`.
- [ ] No hay secretos ni credenciales en el repositorio.
- [ ] PR mergeado a `develop`.
- [ ] Rama `HU-DEV-SALB_01` eliminada del remoto tras el merge.
