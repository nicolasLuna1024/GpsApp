# TopoTracker - Sistema GPS para Topografía

Una aplicación Flutter para el rastreo GPS colaborativo y mapeo de terrenos en tiempo real, diseñada para equipos de topografía.

## 📋 Tabla de Contenidos

- [Descripción General](#-descripción-general)
- [Características Principales](#-características-principales)
- [Arquitectura del Sistema](#-arquitectura-del-sistema)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Documentación de Módulos](#-documentación-de-módulos)
- [Base de Datos](#-base-de-datos)
- [Configuración y Instalación](#-configuración-y-instalación)
- [Uso de la Aplicación](#-uso-de-la-aplicación)
- [Métodos de Acceso a Datos](#-métodos-de-acceso-a-datos)
- [📖 Documentación Técnica de Base de Datos](DATABASE_DOCUMENTATION.md)

## 🎯 Descripción General

TopoTracker es una aplicación móvil desarrollada en Flutter que permite a equipos de topografía trabajar de manera colaborativa en el mapeo y rastreo GPS de terrenos. La aplicación utiliza Supabase como backend para autenticación, base de datos y sincronización en tiempo real.

### Tecnologías Utilizadas

- **Framework**: Flutter 3.8.1+
- **Estado**: BLoC Pattern (flutter_bloc 8.1.5)
- **Backend**: Supabase (autenticación y base de datos)
- **Mapas**: flutter_map 7.0.2 con OpenStreetMap
- **Geolocalización**: geolocator 12.0.0, location 8.0.1
- **Base de Datos**: PostgreSQL (Supabase)

## ✨ Características Principales

### 🔐 Sistema de Autenticación
- Registro e inicio de sesión seguro
- Gestión de perfiles de usuario
- Roles diferenciados (Admin/Topógrafo)
- Autenticación basada en Supabase Auth

### 👥 Gestión de Equipos
- Creación y administración de equipos de trabajo
- Asignación de líderes de equipo
- Gestión de miembros del equipo
- Vista de información detallada del equipo

### 🗺️ Mapeo y Navegación
- Mapa interactivo en tiempo real
- Rastreo GPS preciso con alta frecuencia
- Visualización de ubicaciones de equipo
- Centrado automático en ubicación actual

### 🌍 Mapeo de Terrenos
- Creación de polígonos de terreno por puntos GPS
- Cálculo automático de áreas (m² y hectáreas)
- Almacenamiento de puntos con coordenadas y timestamps
- Lista y gestión de terrenos mapeados

### 🤝 Sesiones Colaborativas
- Creación de sesiones de trabajo en equipo
- Seguimiento en tiempo real de participantes
- Gestión de sesiones activas/inactivas
- Coordinación de actividades de mapeo

### 📊 Panel de Administración
- Dashboard con estadísticas del sistema
- Gestión de usuarios y equipos
- Monitoreo de actividades en tiempo real
- Herramientas de configuración del sistema

## 🏗️ Arquitectura del Sistema

### Patrón BLoC (Business Logic Component)

La aplicación utiliza el patrón BLoC para la gestión de estados, separando la lógica de negocio de la interfaz de usuario:

```
UI Layer (Screens/Widgets)
    ↓
BLoC Layer (State Management)
    ↓
Service Layer (Data Access)
    ↓
Repository Layer (Supabase)
```

### Estructura de Capas

1. **Presentation Layer**: Pantallas y widgets de UI
2. **BLoC Layer**: Gestión de estados y lógica de negocio
3. **Service Layer**: Servicios para acceso a datos
4. **Data Layer**: Modelos y configuración de Supabase

## 📁 Estructura del Proyecto

```
lib/
├── main.dart                 # Punto de entrada de la aplicación
├── bloc/                     # Gestión de estados BLoC
│   ├── auth_bloc.dart
│   ├── location_bloc.dart
│   ├── terrain_bloc.dart
│   ├── team_bloc.dart
│   ├── admin_bloc.dart
│   └── collaborative_session_bloc.dart
├── config/                   # Configuraciones
│   └── supabase_config.dart
├── database/                 # Scripts SQL de base de datos
│   ├── setup.sql
│   ├── add_collaborative_sessions.sql
│   ├── add_terrains_table.sql
│   └── funciones_Equipos.sql
├── models/                   # Modelos de datos
│   ├── user_profile.dart
│   ├── team.dart
│   ├── user_location.dart
│   ├── terrain.dart
│   └── collaborative_session.dart
├── screens/                  # Pantallas de la aplicación
│   ├── login_screen.dart
│   ├── register_screen.dart
│   ├── home_screen.dart
│   ├── map_screen.dart
│   ├── terrain_mapping_screen.dart
│   ├── terrain_list_screen.dart
│   ├── team_info_screen.dart
│   └── admin_screen.dart
├── services/                 # Servicios de acceso a datos
│   ├── auth_service.dart
│   ├── location_service.dart
│   ├── terrain_service.dart
│   ├── team_service.dart
│   ├── admin_service.dart
│   └── collaborative_session_service.dart
├── utils/                    # Utilidades
│   ├── debug_service.dart
│   └── admin_setup.dart
└── widgets/                  # Widgets reutilizables
    ├── team_members_dialog.dart
    ├── collaborative_session_modal.dart
    └── session_badge_wrapper.dart
```

## 📚 Documentación de Módulos

### 🔧 Configuración (`config/`)

#### `supabase_config.dart`
Configuración central de Supabase para toda la aplicación.

**Funcionalidades:**
- Inicialización del cliente Supabase
- Configuración de URL y clave anónima
- Cliente singleton para acceso global

**Métodos principales:**
- `initialize()`: Inicializa la conexión con Supabase
- `client`: Getter para acceder al cliente Supabase

### 📊 Modelos de Datos (`models/`)

#### `user_profile.dart`
Modelo para la gestión de perfiles de usuario.

**Propiedades:**
- `id`: Identificador único del usuario
- `email`: Correo electrónico
- `fullName`: Nombre completo
- `role`: Rol del usuario (admin/topografo)
- `teamId`: ID del equipo al que pertenece
- `isActive`: Estado activo/inactivo
- `avatarUrl`: URL del avatar
- `createdAt`/`updatedAt`: Timestamps de creación y actualización

#### `team.dart`
Modelo para la gestión de equipos de trabajo.

**Propiedades:**
- `id`: Identificador único del equipo
- `name`: Nombre del equipo
- `description`: Descripción del equipo
- `leaderId`: ID del líder del equipo
- `isActive`: Estado activo/inactivo
- `roleInTeam`: Rol del usuario en el equipo
- `isLeader`: Indica si el usuario es líder
- `memberCount`: Número de miembros

#### `user_location.dart`
Modelo para el rastreo de ubicaciones GPS en tiempo real.

**Propiedades:**
- `id`: Identificador único de la ubicación
- `userId`: ID del usuario
- `latitude`/`longitude`: Coordenadas GPS
- `altitude`: Altitud (opcional)
- `accuracy`: Precisión del GPS
- `heading`: Dirección de movimiento
- `speed`: Velocidad
- `collaborativeSessionId`: ID de sesión colaborativa
- `timestamp`: Marca de tiempo
- `isActive`: Estado activo/inactivo

#### `terrain.dart`
Modelo para el mapeo de terrenos.

**Clases:**
- `TerrainPoint`: Punto individual del terreno
  - `latitude`/`longitude`: Coordenadas GPS
  - `altitude`: Altitud (opcional)
  - `timestamp`: Marca de tiempo
  
- `Terrain`: Terreno completo
  - `id`: Identificador único
  - `name`: Nombre del terreno
  - `description`: Descripción
  - `points`: Lista de puntos TerrainPoint
  - `area`: Área calculada en metros cuadrados
  - `userId`: ID del usuario creador
  - `teamId`: ID del equipo
  - `createdAt`/`updatedAt`: Timestamps

**Métodos especiales:**
- `calculateArea()`: Calcula área usando fórmula de Shoelace
- `formattedArea`: Formatea área en m² o hectáreas

#### `collaborative_session.dart`
Modelo para sesiones colaborativas de trabajo.

**Propiedades:**
- `id`: Identificador único de la sesión
- `name`: Nombre de la sesión
- `description`: Descripción
- `teamId`: ID del equipo
- `teamName`: Nombre del equipo
- `createdBy`: ID del creador
- `creatorName`: Nombre del creador
- `participants`: Lista de participantes
- `participantCount`: Número de participantes
- `isParticipant`: Indica si el usuario actual participa
- `isActive`: Estado activo/inactivo

### 🎯 Gestión de Estados BLoC (`bloc/`)

#### `auth_bloc.dart`
Gestiona la autenticación de usuarios.

**Estados:**
- `AuthInitial`: Estado inicial
- `AuthLoading`: Cargando autenticación
- `AuthAuthenticated`: Usuario autenticado
- `AuthUnauthenticated`: Usuario no autenticado
- `AuthError`: Error en autenticación

**Eventos:**
- `AuthStarted`: Iniciar verificación de autenticación
- `AuthLoginRequested`: Solicitar inicio de sesión
- `AuthRegisterRequested`: Solicitar registro
- `AuthLogoutRequested`: Solicitar cierre de sesión

#### `location_bloc.dart`
Gestiona el rastreo GPS y ubicaciones.

**Estados:**
- `LocationInitial`: Estado inicial
- `LocationLoading`: Cargando ubicación
- `LocationLoaded`: Ubicación cargada
- `LocationError`: Error en ubicación

**Eventos:**
- `LocationStartTracking`: Iniciar rastreo GPS
- `LocationStopTracking`: Detener rastreo GPS
- `LocationUpdateReceived`: Actualización de ubicación recibida
- `LocationLoadTeamLocations`: Cargar ubicaciones del equipo

#### `terrain_bloc.dart`
Gestiona el mapeo de terrenos.

**Estados:**
- `TerrainInitial`: Estado inicial
- `TerrainLoading`: Cargando terrenos
- `TerrainLoaded`: Terrenos cargados
- `TerrainMappingInProgress`: Mapeo en progreso
- `TerrainSaved`: Terreno guardado
- `TerrainError`: Error en operación

**Eventos:**
- `TerrainLoadAll`: Cargar todos los terrenos
- `TerrainStartMapping`: Iniciar mapeo
- `TerrainAddPoint`: Agregar punto al mapeo
- `TerrainSave`: Guardar terreno
- `TerrainDelete`: Eliminar terreno

#### `team_bloc.dart`
Gestiona la información de equipos.

**Estados:**
- `TeamInitial`: Estado inicial
- `TeamLoading`: Cargando equipo
- `TeamLoaded`: Equipo cargado
- `TeamError`: Error en operación

**Eventos:**
- `TeamLoadInfo`: Cargar información del equipo
- `TeamLoadMembers`: Cargar miembros del equipo

#### `admin_bloc.dart`
Gestiona funcionalidades administrativas.

**Estados:**
- `AdminInitial`: Estado inicial
- `AdminLoading`: Cargando datos administrativos
- `AdminLoaded`: Datos cargados
- `AdminUserHistoryLoaded`: Historial de usuario cargado
- `AdminSuccess`: Operación exitosa
- `AdminError`: Error en operación

#### `collaborative_session_bloc.dart`
Gestiona sesiones colaborativas.

**Estados:**
- `CollaborativeSessionInitial`: Estado inicial
- `CollaborativeSessionLoading`: Cargando sesiones
- `CollaborativeSessionLoaded`: Sesiones cargadas
- `CollaborativeSessionCreated`: Sesión creada
- `CollaborativeSessionJoined`: Usuario unido a sesión
- `CollaborativeSessionLeft`: Usuario salió de sesión
- `CollaborativeSessionError`: Error en operación

### 🔌 Servicios (`services/`)

#### `auth_service.dart`
Servicio para autenticación de usuarios.

**Métodos principales:**
- `signIn()`: Iniciar sesión
- `signUp()`: Registrar usuario
- `signOut()`: Cerrar sesión
- `getCurrentUser()`: Obtener usuario actual
- `createUserProfile()`: Crear perfil de usuario

#### `location_service.dart`
Servicio para manejo de ubicaciones GPS.

**Métodos principales:**
- `startLocationTracking()`: Iniciar rastreo
- `stopLocationTracking()`: Detener rastreo
- `saveLocationToDatabase()`: Guardar ubicación en BD
- `getTeamActiveLocations()`: Obtener ubicaciones del equipo
- `requestLocationPermission()`: Solicitar permisos

#### `terrain_service.dart`
Servicio para gestión de terrenos.

**Métodos principales:**
- `getUserTerrains()`: Obtener terrenos del usuario
- `saveTerrain()`: Guardar terreno
- `deleteTerrain()`: Eliminar terreno
- `getTerrainById()`: Obtener terreno por ID

#### `team_service.dart`
Servicio para gestión de equipos.

**Métodos principales:**
- `getUserTeam()`: Obtener equipo del usuario
- `getTeamMembers()`: Obtener miembros del equipo
- `getTeamInfo()`: Obtener información del equipo

#### `admin_service.dart`
Servicio para funcionalidades administrativas.

**Métodos principales:**
- `getAllUsers()`: Obtener todos los usuarios
- `getSystemStats()`: Obtener estadísticas del sistema
- `getAllTeams()`: Obtener todos los equipos
- `getUserLocationHistory()`: Obtener historial de ubicaciones

#### `collaborative_session_service.dart`
Servicio para sesiones colaborativas.

**Métodos principales:**
- `createSession()`: Crear sesión colaborativa
- `getTeamSessions()`: Obtener sesiones del equipo
- `joinSession()`: Unirse a sesión
- `leaveSession()`: Salir de sesión
- `endSession()`: Finalizar sesión

### 🖥️ Pantallas (`screens/`)

#### `login_screen.dart`
Pantalla de inicio de sesión con formulario de autenticación.

#### `register_screen.dart`
Pantalla de registro de nuevos usuarios.

#### `home_screen.dart`
Pantalla principal con navegación a diferentes módulos.

#### `map_screen.dart`
Pantalla principal del mapa con rastreo GPS en tiempo real.

**Características:**
- Mapa interactivo con OpenStreetMap
- Marcadores de ubicaciones de equipo
- Centrado automático en ubicación actual
- Controles de rastreo GPS

#### `terrain_mapping_screen.dart`
Pantalla para mapear terrenos creando polígonos.

**Características:**
- Adición de puntos por tap en mapa
- Visualización de polígono en tiempo real
- Cálculo automático de área
- Formulario para guardar terreno

#### `terrain_list_screen.dart`
Pantalla que muestra lista de terrenos guardados.

#### `team_info_screen.dart`
Pantalla con información detallada del equipo.

#### `admin_screen.dart`
Panel de administración del sistema.

### 🧩 Widgets Reutilizables (`widgets/`)

#### `team_members_dialog.dart`
Dialog para mostrar miembros del equipo.

#### `collaborative_session_modal.dart`
Modal para gestión de sesiones colaborativas.

#### `session_badge_wrapper.dart`
Widget para mostrar badges de sesión activa.

### 🛠️ Utilidades (`utils/`)

#### `debug_service.dart`
Servicio para funciones de depuración y logging.

#### `admin_setup.dart`
Utilidades para configuración administrativa.

## 🗄️ Base de Datos

> 📖 **Documentación Completa de Base de Datos**  
> Para información detallada sobre el esquema, funciones, políticas de seguridad, optimización y mantenimiento de la base de datos, consulta: **[DATABASE_DOCUMENTATION.md](DATABASE_DOCUMENTATION.md)**

### Esquema de Base de Datos (PostgreSQL/Supabase)

#### Tabla: `user_profiles`
```sql
CREATE TABLE public.user_profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    role TEXT DEFAULT 'topografo' CHECK (role IN ('admin', 'topografo')),
    team_id UUID,
    is_active BOOLEAN DEFAULT true,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Descripción**: Extiende la tabla de usuarios de Supabase Auth con información de perfil.

**Campos:**
- `id`: Clave primaria que referencia auth.users(id)
- `email`: Correo electrónico del usuario
- `full_name`: Nombre completo del usuario
- `role`: Rol del usuario (admin o topografo)
- `team_id`: Referencia al equipo al que pertenece
- `is_active`: Estado activo/inactivo del usuario
- `avatar_url`: URL del avatar del usuario
- `created_at`: Fecha de creación del perfil
- `updated_at`: Fecha de última actualización

**Relaciones:**
- Uno a uno con `auth.users`
- Muchos a uno con `teams`

#### Tabla: `teams`
```sql
CREATE TABLE public.teams (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    leader_id UUID,
    users_id UUID[],
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Descripción**: Almacena información de equipos de trabajo.

**Campos:**
- `id`: Clave primaria única del equipo
- `name`: Nombre del equipo
- `description`: Descripción del equipo
- `leader_id`: ID del líder del equipo
- `users_id`: Array de IDs de usuarios miembros
- `is_active`: Estado activo/inactivo del equipo
- `created_at`: Fecha de creación del equipo
- `updated_at`: Fecha de última actualización

**Relaciones:**
- Uno a muchos con `user_profiles`
- Uno a muchos con `collaborative_sessions`
- Uno a muchos con `terrains`

#### Tabla: `user_locations`
```sql
CREATE TABLE public.user_locations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.user_profiles(id) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    altitude DECIMAL(8, 3),
    accuracy DECIMAL(8, 3),
    heading DECIMAL(6, 3),
    speed DECIMAL(8, 3),
    collaborative_session_id UUID,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);
```

**Descripción**: Almacena ubicaciones GPS de usuarios en tiempo real.

**Campos:**
- `id`: Clave primaria única de la ubicación
- `user_id`: ID del usuario (clave foránea)
- `latitude`: Latitud GPS (precisión de 8 decimales)
- `longitude`: Longitud GPS (precisión de 8 decimales)
- `altitude`: Altitud en metros
- `accuracy`: Precisión del GPS en metros
- `heading`: Dirección en grados (0-360)
- `speed`: Velocidad en metros por segundo
- `collaborative_session_id`: ID de sesión colaborativa (opcional)
- `timestamp`: Marca de tiempo de la ubicación
- `is_active`: Indica si es la ubicación actual activa

**Relaciones:**
- Muchos a uno con `user_profiles`
- Muchos a uno con `collaborative_sessions` (opcional)

#### Tabla: `terrains`
```sql
CREATE TABLE public.terrains (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    points JSONB NOT NULL,
    area DECIMAL(15, 6) NOT NULL,
    user_id UUID REFERENCES public.user_profiles(id) NOT NULL,
    team_id UUID REFERENCES public.teams(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);
```

**Descripción**: Almacena terrenos mapeados con sus polígonos.

**Campos:**
- `id`: Clave primaria única del terreno
- `name`: Nombre del terreno
- `description`: Descripción del terreno
- `points`: Array JSON de puntos del polígono
- `area`: Área calculada en metros cuadrados
- `user_id`: ID del usuario creador (clave foránea)
- `team_id`: ID del equipo (clave foránea)
- `created_at`: Fecha de creación del terreno
- `updated_at`: Fecha de última actualización
- `is_active`: Estado activo/inactivo del terreno

**Estructura del campo `points` (JSONB):**
```json
[
  {
    "latitude": -33.4569,
    "longitude": -70.6483,
    "altitude": 547.2,
    "timestamp": "2024-01-15T10:30:00Z"
  }
]
```

**Relaciones:**
- Muchos a uno con `user_profiles`
- Muchos a uno con `teams`

#### Tabla: `collaborative_sessions`
```sql
CREATE TABLE public.collaborative_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    team_id UUID REFERENCES public.teams(id),
    created_by UUID REFERENCES public.user_profiles(id) NOT NULL,
    participants UUID[] DEFAULT array[]::UUID[],
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**Descripción**: Gestiona sesiones colaborativas de trabajo en equipo.

**Campos:**
- `id`: Clave primaria única de la sesión
- `name`: Nombre de la sesión colaborativa
- `description`: Descripción de la sesión
- `team_id`: ID del equipo (clave foránea)
- `created_by`: ID del usuario creador (clave foránea)
- `participants`: Array de IDs de usuarios participantes
- `is_active`: Estado activo/inactivo de la sesión
- `created_at`: Fecha de creación de la sesión
- `updated_at`: Fecha de última actualización

**Relaciones:**
- Muchos a uno con `teams`
- Muchos a uno con `user_profiles` (creador)
- Uno a muchos con `user_locations`

### Políticas de Seguridad (RLS - Row Level Security)

#### Políticas para `user_profiles`
- Los usuarios pueden ver su propio perfil
- Los usuarios pueden actualizar su propio perfil
- Los usuarios pueden ver perfiles del mismo equipo

#### Políticas para `teams`
- Los miembros pueden ver su equipo

#### Políticas para `user_locations`
- Los usuarios pueden insertar su propia ubicación
- Los usuarios pueden ver ubicaciones del mismo equipo
- Los usuarios pueden actualizar su propia ubicación
- Los usuarios pueden ver su propia ubicación

#### Políticas para `terrains`
- Los usuarios pueden crear sus propios terrenos
- Los usuarios pueden ver sus propios terrenos
- Los usuarios pueden ver terrenos del mismo equipo
- Los usuarios pueden actualizar sus propios terrenos

#### Políticas para `collaborative_sessions`
- Los miembros del equipo pueden ver sesiones
- Los miembros del equipo pueden crear sesiones
- Solo el creador puede actualizar sesiones

### Funciones de Base de Datos

#### `handle_new_user()`
Función trigger que se ejecuta automáticamente cuando se crea un nuevo usuario en Supabase Auth.

**Funcionalidad:**
- Crea automáticamente un perfil en `user_profiles`
- Extrae información del metadata del usuario
- Asigna rol por defecto 'topografo'

#### `update_updated_at_column()`
Función trigger para actualizar automáticamente el campo `updated_at`.

#### `create_collaborative_session()`
Función para crear sesiones colaborativas con validaciones.

**Validaciones:**
- Verifica que el usuario pertenece al equipo
- Verifica que no hay otra sesión activa para el equipo
- Crea la sesión y retorna el ID

#### `get_team_collaborative_sessions()`
Función para obtener sesiones colaborativas de un equipo.

#### `end_collaborative_session()`
Función para finalizar una sesión colaborativa.

**Validaciones:**
- Solo el creador puede finalizar la sesión
- Marca la sesión como inactiva

### Índices de Base de Datos

#### Índices de Rendimiento
```sql
-- Índice para consultas frecuentes de ubicaciones activas
CREATE INDEX idx_user_locations_active_user ON public.user_locations(user_id, is_active);

-- Índice para consultas de terrenos por usuario
CREATE INDEX idx_terrains_user_active ON public.terrains(user_id, is_active);

-- Índice para consultas de sesiones colaborativas activas
CREATE INDEX idx_collaborative_sessions_team_active ON public.collaborative_sessions(team_id, is_active);

-- Índice para consultas de ubicaciones por timestamp
CREATE INDEX idx_user_locations_timestamp ON public.user_locations(timestamp DESC);
```

### Triggers de Base de Datos

#### `on_auth_user_created`
```sql
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

#### `update_updated_at_*`
Triggers para actualizar automáticamente `updated_at` en todas las tablas:
```sql
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
```

## ⚙️ Configuración y Instalación

### Requisitos Previos

- Flutter 3.8.1 o superior
- Dart SDK
- Cuenta de Supabase
- Editor (VS Code/Android Studio)

### Instalación

1. **Clonar el repositorio:**
```bash
git clone <repository-url>
cd GpsApp
```

2. **Instalar dependencias:**
```bash
flutter pub get
```

3. **Configurar Supabase:**
- Crear proyecto en [supabase.com](https://supabase.com)
- Obtener URL y clave anónima
- Actualizar `lib/config/supabase_config.dart`:

```dart
static const String supabaseUrl = "tu_supabase_url_aqui";
static const String supabaseAnonKey = 'tu_supabase_anon_key_aqui';
```

4. **Configurar base de datos:**
- Ejecutar scripts SQL en orden:
  1. `lib/database/setup.sql`
  2. `lib/database/add_collaborative_sessions.sql`
  3. `lib/database/funciones_Equipos.sql`

5. **Configurar permisos:**
- Android: Permisos de ubicación en `android/app/src/main/AndroidManifest.xml`
- iOS: Permisos en `ios/Runner/Info.plist`

### Dependencias Principales

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  supabase_flutter: ^2.5.6
  flutter_bloc: ^8.1.5
  formz: ^0.7.0
  fluttertoast: ^8.2.6
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  geolocator: ^12.0.0
  permission_handler: ^11.3.1
  location: ^8.0.1
  uuid: ^4.4.2
```

## 📱 Uso de la Aplicación

### Flujo de Usuario

1. **Registro/Login**: Usuario se registra o inicia sesión
2. **Asignación a Equipo**: Admin asigna usuario a equipo
3. **Pantalla Principal**: Acceso a todas las funcionalidades
4. **Mapa GPS**: Visualización y rastreo en tiempo real
5. **Mapeo de Terrenos**: Creación de polígonos por puntos
6. **Sesiones Colaborativas**: Coordinación de trabajo en equipo

### Roles y Permisos

#### Administrador
- Gestión completa de usuarios y equipos
- Acceso a panel de administración
- Visualización de estadísticas del sistema
- Configuración de equipos

#### Topógrafo
- Rastreo GPS personal
- Mapeo de terrenos
- Participación en sesiones colaborativas
- Visualización de datos del equipo

## 🚀 Métodos de Acceso a Datos

### Servicios de Autenticación

La aplicación utiliza Supabase Auth y el SDK de Supabase para todas las operaciones:

**Métodos principales:**
- `signUp()`: Registro de usuario con Supabase Auth
- `signIn()`: Inicio de sesión con Supabase Auth  
- `signOut()`: Cierre de sesión
- `getCurrentUserProfile()`: Obtener perfil del usuario desde `user_profiles`

### Servicios de Ubicación

**Métodos de acceso a datos:**
- `saveLocationToDatabase()`: Inserta ubicaciones en `user_locations`
- `getTeamActiveLocations()`: Consulta ubicaciones activas del equipo
- `getUserLocationHistory()`: Historial de ubicaciones por usuario
- `setLocationInactive()`: Actualiza estado de ubicaciones

### Servicios de Terrenos

**Métodos CRUD:**
- `saveTerrain()`: Inserta nuevos terrenos en tabla `terrains`
- `getUserTerrains()`: Consulta terrenos del usuario actual
- `getTeamTerrains()`: Consulta terrenos del equipo
- `updateTerrain()`: Actualiza datos de terreno existente
- `deleteTerrain()`: Marca terreno como inactivo

### Servicios de Equipos

**Métodos de consulta:**
- `getUserTeams()`: Obtiene equipos usando función RPC `get_user_teams`
- `getTeamMembers()`: Obtiene miembros usando función RPC `get_team_members`
- `getCurrentUserTeam()`: Obtiene equipo actual del usuario

### Servicios de Sesiones Colaborativas

**Métodos de gestión:**
- `createSession()`: Crea sesión usando función RPC `create_collaborative_session`
- `getTeamSessions()`: Obtiene sesiones usando función RPC `get_user_team_sessions`
- `joinSession()`: Actualiza array de participantes
- `endSession()`: Marca sesión como inactiva

### Servicios Administrativos

**Métodos de administración:**
- `getAllUsers()`: Consulta todos los perfiles de usuario
- `getSystemStats()`: Genera estadísticas del sistema
- `createTeam()`: Inserta nuevos equipos
- `assignUserToTeam()`: Actualiza `team_id` en `user_profiles`
- `removeUserFromTeam()`: Elimina usuario del array `users_id`

---

**Versión**: 1.0.0
**Última actualización**: Agosto 2025
**Desarrollado con**: Flutter + Supabase
