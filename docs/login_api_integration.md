# Integración del login con FastAPI

Contrato consultado el 18 de noviembre de 2026 en:
https://controltec-tksj.onrender.com/docs
https://controltec-tksj.onrender.com/openapi.json

## Estado y autorización

El módulo de autenticación implementa el contrato real y conserva la pantalla,
validaciones, SnackBars y navegación actuales. El trabajo de la pantalla principal
no se modificó. La aplicación selecciona el contrato real y la URL de Render por
defecto. El mock solo se habilita explícitamente en desarrollo.

Por la restricción de no editar archivos compartidos sin autorización, primero se
preparó y verificó un ajuste de dos archivos en una copia temporal. El usuario
autorizó expresamente ambos cambios y se aplicaron al proyecto principal:

- `lib/api/app_config.dart`: modo real por defecto, URL de Render por defecto y
  conservación de `USE_MOCK_AUTH` / `API_BASE_URL` como opciones de configuración.
- `lib/api/app_dependencies.dart`: seleccionar `FastApiAuthContract` en la rama
  real. El bloque de `MyDayService`, el cliente compartido y su ciclo de vida no
  cambian.

`login_api_activation.patch` conserva el ajuste aprobado como registro de revisión;
ya está aplicado. No se ha usado el nombre del contrato pendiente para activar
silenciosamente otro comportamiento.

## Contrato confirmado

`POST /auth/mobile/login`, `Content-Type: application/json`:

```json
{"email": "correo@ejemplo.com", "password": "contraseña", "door": "staff"}
```

Swagger exige `email` con formato de correo y `password` de hasta 72 caracteres.
`door` es opcional (`staff`, `customer` o null); la app selecciona `staff`.
No se recorta la contraseña ni se añade información distinta al contrato.

Respuesta `200`, esquema `MobileSessionRead`:

```json
{
  "user": {
    "id": "identificador",
    "full_name": "Nombre del técnico",
    "role": "technician",
    "active": true,
    "email": "correo@ejemplo.com",
    "avatar_url": null,
    "has_signature": false,
    "capabilities": ["field:access"]
  },
  "access_token": "<token recibido, nunca registrado>",
  "refresh_token": "<token recibido, nunca registrado>",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_expires_in": 604800
}
```

Los tiempos son ilustrativos; la app lee los valores reales del servidor.
Son obligatorios `user`, ambos tokens y ambos tiempos. `token_type` tiene valor
predeterminado `bearer`. En el usuario son obligatorios `id`, `full_name`, `role` y
`active`; los demás campos son opcionales según Swagger. Los DTO conservan esta
información y rechazan respuestas inválidas o cuentas inactivas/de clientes.

La ruta coincide con la prevista. El cambio respecto a la preparación anterior es
que login y refresh ya incluyen el usuario: no se hace un GET adicional a `/me`
para completar cada autenticación.

También existen:

| Operación | Petición | Respuesta |
| --- | --- | --- |
| POST `/auth/mobile/refresh` | JSON `{"refresh_token":"..."}`, sin Bearer | `200 MobileSessionRead` con un nuevo par de tokens |
| POST `/auth/mobile/logout` | JSON con `refresh_token`; Bearer disponible | `204`, sin cuerpo |
| GET `/auth/mobile/me` | `Authorization: Bearer ...` | `200`, `{"user": SessionUserRead}` |

Refresh conserva una única solicitud en curso para evitar reutilizar un token que
el servidor acaba de rotar. Estas operaciones existentes quedan adaptadas al
contrato, sin añadir pantallas, interceptores de la jornada ni módulos nuevos.

## Errores

Swagger documenta `200`, `403` y `422` para login; una prueba negativa controlada
con la cuenta demo confirmó además `401` con `{"detail": "..."}`. `422` usa
`HTTPValidationError`, con `detail` como lista de objetos `loc`, `msg`, `type` y
posible `input`. Ese contenido puede incluir la contraseña enviada: la app no lo
muestra ni registra; traduce el estado a un aviso seguro.

| Situación | Mensaje |
| --- | --- |
| Campos vacíos | Rellene todos los campos |
| Correo inválido | Ingrese un correo electrónico válido |
| HTTP 401 | Correo electrónico o contraseña incorrectos |
| HTTP 403 | Esta cuenta no tiene acceso a la app de campo |
| HTTP 400/422 | Revise los datos ingresados e intente nuevamente |
| Fallo de conexión | No se pudo conectar. Intente nuevamente |
| Timeout | El servidor tardó demasiado en responder. Intente nuevamente |
| HTTP 5xx | El servidor no está disponible. Intente más tarde |
| Éxito con cuerpo inválido | La respuesta del servidor no es válida. Intente nuevamente |

El timeout de login es de 90 segundos para tolerar el arranque en frío de Render.
No se reintentan automáticamente contraseñas ni solicitudes de login. Los avisos
usan los SnackBars existentes, conservando rojo/blanco y tres segundos.

## Tokens y pantalla principal

Se reutiliza `SecureTokenStore` sin modificar su formato ni implementación.
Los tokens se escriben juntos en `controltec.auth.tokens.v1` mediante
`flutter_secure_storage`; no se guardan contraseñas. El controlador establece la
sesión y permite navegar solo cuando la escritura termina correctamente.

`MyDayService` sigue leyendo ese mismo almacén y `MyDayApi` sigue enviando Bearer.
No se crea un manejo de sesión paralelo. El nombre del usuario se entrega a
`HomeScreen` por la navegación existente, sin modificar `main.dart` ni la pantalla.
Las duraciones de tokens se conservan en el DTO de sesión; no se incorpora
restauración de sesión o renovación automática de la jornada en esta etapa.

El mock sigue separado y bloqueado en release. Solo se activa explícitamente en
desarrollo con `--dart-define=USE_MOCK_AUTH=true`. `flutter run` usa FastAPI por
defecto, y `API_BASE_URL` permite cambiar el servidor si se necesita.

## Archivos del módulo modificados

- `lib/api/services/auth_api_contract.dart`: contrato real y conversión de sesión.
- `lib/api/services/login_api.dart`: errores por estado y timeout de login.
- `lib/api/services/login_service.dart`: sesión devuelta en login, persistencia
  previa a navegación y adaptación de refresh/perfil.
- `lib/api/services/auth_session_api.dart`: descripción actualizada.
- `lib/models/auth_response_dto.dart`: `MobileSessionRead` y duraciones.
- `lib/models/technician.dart`: `SessionUserRead`, preservando la API usada por home.
- `lib/models/user_credentials_dto.dart`: documentación de `LoginRequest`.
- `test/auth_test.dart`, `test/handlers_test.dart`, `test/login_service_test.dart`:
  adaptación al contrato y al uso explícito de mock en las pruebas de desarrollo.
- `test/fastapi_login_test.dart`: contrato real con HTTP simulado, fallos,
  almacenamiento seguro simulado, interoperabilidad con la jornada y navegación.
- `test/login_activation_test.dart`: configuración real por defecto, selección
  del contrato y reutilización del cliente HTTP.
- `lib/api/app_config.dart` y `lib/api/app_dependencies.dart`: los dos ajustes
  compartidos autorizados, exclusivamente para activar el login real.
- Este documento y `login_api_activation.patch`: entrega/revisión del ajuste final.

No se modificaron la pantalla principal, los servicios ni modelos de la jornada,
`visit_card.dart`, el tema, las clases base, los componentes visuales, `main.dart`,
las rutas compartidas, el almacén seguro ni el README del compañero. En el archivo
compartido de dependencias solo cambió la selección del contrato de autenticación;
el bloque de `MyDayService` conserva exactamente su implementación.

## Verificación

- El esquema se descargó del servidor real, sin adivinar contratos.
- Una cuenta demo documentada en el README obtuvo login `200`, perfil `200`, jornada
  `200` con esquema compatible y logout `204`. La sesión de prueba quedó cerrada.
  No se imprimieron ni persistieron esos tokens en archivos del proyecto.
- Una única prueba negativa con la cuenta demo documentada confirmó `401` y
  `detail` de texto. Los demás errores, desconexión y espera agotada se verifican
  con HTTP simulado, sin usar cuentas de producción ni adivinar contraseñas.
- `flutter test`: 81 pruebas aprobadas antes de activar los archivos compartidos.
- La copia temporal con el parche de activación y una prueba adicional de la
  configuración predeterminada aprobó 82 pruebas.
- Después de la autorización y activación, el proyecto principal aprobó también
  **82 pruebas** con la configuración real predeterminada.
- `flutter pub get` completado, `flutter analyze` sin problemas y
  `git diff --check` sin errores. Solo se formatearon archivos de login modificados.
- No se probó en un dispositivo físico. Las pruebas de almacenamiento simulan el
  plugin y no sustituyen la validación de Keychain/Keystore en Android/iOS.
