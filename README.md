# Servicios de desarrollo con Docker

Servicios compartidos para desarrollo local: bases de datos, caché y captura de correo. Todos corren en contenedores con Docker Compose y se conectan a una red común (`shared-network`) para que los proyectos los puedan usar.

> Esta copia vive en `~/.docker-services/` y ya **no** está ligada al repositorio de origen. Los cambios se hacen directamente aquí.

## Servicios

| Servicio | Imagen | Puerto(s) | Uso |
|---|---|---|---|
| **PostgreSQL** | `postgres:17` | `5432` | Base de datos principal |
| **MySQL** | `mysql:8.0` | `3306` | Base de datos MySQL |
| **Redis** | `redis:7-alpine` | `6379` | Caché / colas |
| **Mailpit** | `axllent/mailpit` | `1025` (SMTP), `8025` (web) | Captura los correos que envían las apps |

Todos los contenedores usan `restart: unless-stopped`: arrancan solos con Docker hasta que los detengas a mano.

## Estructura

```
.docker-services/
├── README.md
└── services/
    ├── docker-compose.yml          # Definición de los servicios
    ├── .env.example                # Plantilla de variables
    ├── .env                        # Tus credenciales (se crea a partir del ejemplo)
    └── init-scripts/
        └── 01-create-databases.sql # Bases de PostgreSQL que se crean al iniciar
```

## Puesta en marcha

```bash
cd ~/.docker-services/services

# 1. Crear el archivo de variables y ajustar las credenciales
cp .env.example .env
$EDITOR .env

# 2. Levantar los servicios
docker compose up -d

# 3. Revisar que estén corriendo
docker compose ps
```

## Variables de entorno (`services/.env`)

| Variable | Descripción |
|---|---|
| `POSTGRES_DB` | Base de datos que se crea por defecto en PostgreSQL |
| `POSTGRES_USER` | Usuario de PostgreSQL |
| `POSTGRES_PASSWORD` | Contraseña de PostgreSQL |
| `MYSQL_ROOT_PASSWORD` | Contraseña del usuario `root` de MySQL |
| `PGADMIN_EMAIL` / `PGADMIN_PASSWORD` | Reservadas para pgAdmin (todavía no hay un servicio que las use) |

## Conexión desde tus proyectos

**Desde el equipo** (apps que corren fuera de Docker), usa `localhost`:

| Servicio | Conexión |
|---|---|
| PostgreSQL | `postgresql://$POSTGRES_USER:$POSTGRES_PASSWORD@localhost:5432/<base>` |
| MySQL | `mysql://root:$MYSQL_ROOT_PASSWORD@localhost:3306/<base>` |
| Redis | `redis://localhost:6379` |
| Mailpit SMTP | host `localhost`, puerto `1025`, sin autenticación ni TLS |
| Mailpit web | <http://localhost:8025> |

**Desde otro contenedor**, únelo a la red `shared-network` y usa el nombre del contenedor como host (`postgres`, `mysql`, `redis`, `mailpit`):

```yaml
# docker-compose.yml de tu proyecto
services:
  app:
    # ...
    networks:
      - shared-network

networks:
  shared-network:
    external: true
```

## Bases de datos de PostgreSQL

`init-scripts/01-create-databases.sql` crea estas bases si no existen:

- `tickets`
- `reports`
- `kendo`
- `test`

Para agregar otra, copia uno de los bloques del archivo:

```sql
SELECT 'CREATE DATABASE mi_base'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = 'mi_base'
)\gexec
```

> **Importante:** PostgreSQL solo ejecuta los scripts de `init-scripts/` la **primera vez**, cuando el volumen de datos está vacío. Si el volumen ya existe, crea la base a mano:
>
> ```bash
> docker exec -it postgres sh -c 'psql -U "$POSTGRES_USER" -c "CREATE DATABASE mi_base;"'
> ```
>
> o reinicia desde cero (borra **todos** los datos de PostgreSQL):
>
> ```bash
> docker compose down
> docker volume rm services_postgres-data
> docker compose up -d
> ```

## Datos persistentes

Los datos se guardan en volúmenes de Docker con nombre: `postgres-data`, `mysql-data` y `redis-data`. Compose les antepone el nombre del proyecto (por defecto, el de la carpeta: `services_postgres-data`, etc.). Sobreviven a `docker compose down`, pero **no** a `docker compose down -v`.

```bash
docker volume ls | grep services_
```

## Comandos útiles

Ejecútalos desde `~/.docker-services/services`:

```bash
docker compose up -d              # Levantar todo
docker compose up -d postgres     # Levantar solo un servicio
docker compose stop               # Detener sin borrar contenedores
docker compose down               # Detener y borrar contenedores (los datos se conservan)
docker compose logs -f postgres   # Ver los logs de un servicio
docker compose pull && docker compose up -d   # Actualizar imágenes

docker exec -it postgres sh -c 'psql -U "$POSTGRES_USER"'   # Consola de PostgreSQL
docker exec -it mysql mysql -uroot -p               # Consola de MySQL
docker exec -it redis redis-cli                     # Consola de Redis
```

## Problemas comunes

- **`port is already allocated`:** otro proceso usa el puerto (por ejemplo, un PostgreSQL instalado en el sistema). Detenlo o cambia el puerto del lado del host en `docker-compose.yml` (`"5433:5432"`).
- **`network shared-network not found`** en otro proyecto: levanta primero estos servicios, que son los que crean la red.
- **No aparece una base de datos nueva:** revisa la nota sobre `init-scripts` más arriba.
