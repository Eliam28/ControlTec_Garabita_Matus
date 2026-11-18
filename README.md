# ControlTec Campo

Aplicación Flutter para el personal de campo de ControlTec. Esta etapa incluye el
inicio de sesión y una pantalla principal con «Trabajando en ello :)».

## Ejecutar

```sh
flutter pub get
flutter run --dart-define=USE_MOCK_AUTH=true
```

Credenciales de desarrollo: `tecnico@controltec.com` / `Tecnico123`.
Los campos comienzan vacíos. El mock no hace peticiones HTTP, no crea un cliente,
no almacena credenciales ni genera tokens. Mantiene únicamente la sesión en memoria.
El modo mock se habilita por defecto en debug/profile y siempre se bloquea en
release, tanto desde la configuración como en `MockLoginApi` y `LoginService`.

## API demo

Hay una API de demostración desplegada solo para este proyecto. Sus datos son
inventados y no tiene relación con datos reales de ControlTec.

| Qué | Valor |
| --- | --- |
| URL base | `https://controltec-tksj.onrender.com` |
| Documentación (Swagger) | `https://controltec-tksj.onrender.com/docs` |
| Técnico 1 | `demo.tecnico1@example.com` / `DemoUni2026!` |
| Técnico 2 | `demo.tecnico2@example.com` / `DemoUni2026!` |

```sh
flutter run --dart-define=USE_MOCK_AUTH=false --dart-define=API_BASE_URL=https://controltec-tksj.onrender.com
```

Está en un plan gratuito: si nadie la usa en 15 minutos se duerme, y la primera
petición tarda alrededor de un minuto en responder. Abre `/docs` en el navegador
para despertarla antes de probar la app. Cada técnico tiene servicios agendados
para hoy y los dos días siguientes.

## Arquitectura de referencia

Se revisó primero el código de [flutter-movil-app del profesor Luis Mejía Poot](https://github.com/LuisMejiaPoot/flutter-movil-app),
en particular sus clases `Handler`, `AbstractApiHandler`, `AbstractServiceHandler`,
`CustomException`, `LoginApi`, `LoginService`, los DTO y la inyección en `main.dart`.
Se adaptaron sus responsabilidades a ControlTec; no se copiaron URLs, credenciales
ni modelos de DummyJSON.

El patrón utiliza `execute(input)` como entrada y `doExecute(input)` como operación
que implementa cada clase concreta. Se conservó el controlador existente para el
estado de presentación y las validaciones; las clases base no dependen de pantallas.

```text
LoginScreen
    -> LoginController (validación, carga y prevención de duplicados)
    -> LoginService.execute(UserCredentialsDto)
       -> AbstractServiceHandler.execute / runSafely
       -> LoginService.doExecute
       -> Handler<UserCredentialsDto, String>.execute
          -> MockLoginApi: respuesta local, sin HTTP
          -> LoginApi: AbstractApiHandler -> POST /auth/mobile/login
       -> AuthResponseDto (respuesta interna o mapeo del contrato real)
    -> HomeScreen
```

- `Handler<I, O>` define la entrada y salida de una operación asíncrona.
- `AbstractApiHandler<I, O>` reutiliza GET, POST, PUT y DELETE, valida la URL,
  conserva prefijos como `/api`, aplica timeout y valida el estado HTTP. Recibe
  un cliente inyectado y devuelve el texto de la respuesta, sin convertir DTO.
  Recibe el cuerpo ya codificado y su tipo de contenido; no presupone JSON.
- `AbstractServiceHandler<I, O>` ejecuta la operación, conserva `CustomException`
  y convierte fallos de red, timeout y errores inesperados en mensajes seguros.
- `CustomException` contiene un mensaje presentable, un código opcional y el estado
  HTTP opcional. No incluye respuestas crudas del servidor.
- `LoginApi` prepara y envía exclusivamente la petición de login.
- `LoginService` recibe un `Handler`, transforma respuestas en DTO y conserva la
  preparación del manejo de tokens y perfil. No llama directamente al cliente HTTP.
- `AuthSessionApi` reutiliza el mismo transporte para la preparación existente de
  refresh, logout y perfil. No se añadieron pantallas ni flujos nuevos.

`main.dart` inicializa Flutter, configura tema/rutas y crea las dependencias una
sola vez mediante `AppDependencies.fromConfig`. En modo real se comparte un único
`http.Client` entre `LoginApi` y `AuthSessionApi`; el contenedor lo cierra al liberar
la aplicación. Los servicios inyectados por un llamador externo siguen siendo
responsabilidad de ese llamador. `LoginScreen` recibe el controlador conectado al
servicio seleccionado; cambiar de modo no modifica la pantalla.

## Árbol completo de lib/

```text
lib/
├── api/
│   ├── api_routes.dart
│   ├── app_config.dart
│   ├── app_dependencies.dart
│   ├── auth_messages.dart
│   └── services/
│       ├── auth_api_contract.dart
│       ├── auth_session_api.dart
│       ├── login_api.dart
│       ├── login_service.dart
│       ├── mock_login_api.dart
│       ├── services.md
│       └── token_store.dart
├── base/
│   ├── abstract_api_handler.dart
│   ├── abstract_service_handler.dart
│   ├── custom_exception.dart
│   └── handler.dart
├── models/
│   ├── auth_request_body.dart
│   ├── auth_response_dto.dart
│   ├── auth_tokens.dart
│   ├── models.md
│   ├── technician.dart
│   └── user_credentials_dto.dart
├── screens/
│   ├── app_routes.dart
│   ├── controllers/
│   │   └── login_controller.dart
│   ├── home_screen.dart
│   ├── login_screen.dart
│   ├── screens.md
│   └── validators/
│       └── auth_validator.dart
├── theme/
│   ├── app_theme.dart
│   └── theme.md
├── widgets/
│   ├── app_brand.dart
│   ├── app_snack_bar.dart
│   ├── auth_text_field.dart
│   ├── login_button.dart
│   └── widgets.md
└── main.dart
```

## Archivos reorganizados

| Antes | Ahora / responsabilidad |
| --- | --- |
| `base/app_config.dart` | `api/app_config.dart`, `api/api_routes.dart` y `screens/app_routes.dart` |
| `base/app_dependencies.dart` | `api/app_dependencies.dart`; selecciona el handler y comparte el cliente real |
| `base/auth_messages.dart` | `api/auth_messages.dart`; mismos mensajes |
| `base/auth_validator.dart` | `screens/validators/auth_validator.dart`; mismas validaciones |
| `base/login_controller.dart` | `screens/controllers/login_controller.dart`; ahora ejecuta `LoginService` |
| `models/auth_credentials.dart` | `models/user_credentials_dto.dart`; DTO con serialización interna |
| `models/auth_session.dart` | `models/auth_response_dto.dart`; respuesta mock/API y serialización interna |
| `api/services/mock_auth_service.dart` | `MockLoginApi` comprueba credenciales; `LoginService` conserva la sesión |
| `api/services/api_auth_service.dart` | Transporte común en `AbstractApiHandler`, peticiones en `LoginApi`/`AuthSessionApi` y transformación en `LoginService` |
| `api/services/auth_service.dart` | Contrato común `Handler`; error común `CustomException`, sin una interfaz duplicada |
| `AuthRequestBody` dentro de `auth_api_contract.dart` | Modelo propio `models/auth_request_body.dart` |
| `base/base.md` | Se retiró su descripción genérica; esta documentación explica las clases base. `base/` contiene exclusivamente los cuatro archivos solicitados |
| `test/api_auth_service_test.dart` | `test/login_service_test.dart`; mismos escenarios REST simulados |

También se adaptaron `auth_api_contract.dart`, `token_store.dart`, `auth_tokens.dart`
y `technician.dart` para reutilizar los DTO y su serialización. Se modificó
`main.dart` para inyectar `LoginService`. En `LoginScreen` solo cambiaron imports;
`HomeScreen`, el tema y los cuatro widgets conservaron exactamente su código.
Se actualizaron `test/auth_test.dart` y `test/login_screen_test.dart`, se movió la
fixture asíncrona a `test/support/pending_login_api.dart` y se añadió
`test/handlers_test.dart`. Este README reemplaza la documentación anterior.

No se añadieron dependencias durante la refactorización. Se conservan `http` y
`flutter_secure_storage`, junto con la configuración Android/iOS ya existente.

## DTO y contrato FastAPI

`UserCredentialsDto` representa correo/contraseña. `AuthResponseDto` representa
la sesión y contiene `Technician` y, solo en modo real, `AuthTokens`.
Sus métodos `toJson`/`fromJson` describen **un formato interno de mock, pruebas o
almacenamiento**, no un contrato confirmado del backend. Las claves locales del
almacenamiento seguro se conservaron para no cambiar su formato.

La serialización de peticiones reales y la deserialización de tokens/perfil siguen
aisladas en `AuthApiContract`. Los endpoints documentados no especifican esquemas
JSON ni tipos de contenido, por lo que `PendingAuthApiContract` muestra el aviso de
configuración antes de enviar credenciales. No autentica contra un backend real.

| Método | Ruta | Estado |
| --- | --- | --- |
| POST | `/auth/mobile/login` | Mock funcional; HTTP preparado mediante `LoginApi` |
| POST | `/auth/mobile/refresh` | Preparación existente conservada en `AuthSessionApi` |
| POST | `/auth/mobile/logout` | Preparación existente conservada en `AuthSessionApi` |
| GET | `/auth/mobile/me` | Preparación existente conservada; usa Bearer |

Cuando esté disponible OpenAPI:

1. Implementar `AuthApiContract` con los cuerpos, tipos de contenido y campos de
   respuesta confirmados. Definir cómo refresh renueva/rota los tokens.
2. Reemplazar `PendingAuthApiContract` en `AppDependencies.fromConfig` por ese
   adaptador. No cambian `LoginScreen` ni el controlador.
3. Seleccionar el modo real y configurar la URL HTTPS:

   ```sh
   flutter run --dart-define=USE_MOCK_AUTH=false --dart-define=API_BASE_URL=https://api.example.com
   ```

El servicio real conserva el comportamiento anterior: escribe los tokens después
de completar login y perfil, guarda el par rotado antes de consultar de nuevo el perfil
y elimina los tokens locales al cerrar sesión aunque falle la invalidación remota.
No guarda contraseñas ni implementa todavía renovación automática o restauración
de sesión al arrancar. El almacenamiento seguro usa Keychain en iOS y el cifrado
del plugin en Android. No existe conexión directa con Supabase.

## Verificación

```sh
flutter pub get
dart format .
flutter analyze
flutter test
```

Se ejecutaron las 48 pruebas anteriores como referencia antes de la refactorización
y se conservaron todos sus escenarios. La suite incorpora pruebas adicionales del
transporte GET/POST/PUT/DELETE, tratamiento seguro de errores, serialización de DTO,
ausencia de cliente HTTP en modo mock y uso/cierre de un único cliente en modo real.

Resultado de la verificación de esta refactorización: `flutter pub get` y
`dart format .` completados, `flutter analyze` sin problemas y `flutter test`
con **59 pruebas aprobadas**. `git diff --check` no detectó errores de formato.

Las pruebas de pantalla comprueban campos vacíos, correo inválido, credenciales
incorrectas/correctas, visibilidad de contraseña, recuperación, botón siempre azul,
avisos de tres segundos que se reemplazan, bloqueo de duplicados, navegación sin
regreso al login, teclado, tamaños pequeños y texto ampliado. Se comprobó además
que `LoginScreen` solo cambió imports y que tema/widgets no cambiaron.

Los tests REST y de almacenamiento usan simulaciones locales. Queda pendiente
validar FastAPI y el almacenamiento seguro en dispositivos físicos cuando esté
listo el contrato real.
