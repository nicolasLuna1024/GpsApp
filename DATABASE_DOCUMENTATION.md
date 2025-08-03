# 🗄️ Documentación Técnica de Base de Datos - TopoTracker

## 📋 Tabla de Contenidos

- [Arquitectura de Base de Datos](#-arquitectura-de-base-de-datos)
- [Esquema Relacional](#-esquema-relacional)
- [Diccionario de Datos](#-diccionario-de-datos)
- [Funciones y Procedimientos](#-funciones-y-procedimientos)
- [Políticas de Seguridad (RLS)](#-políticas-de-seguridad-rls)
- [Índices y Optimización](#-índices-y-optimización)
- [Triggers y Automatización](#-triggers-y-automatización)
- [Scripts de Instalación](#-scripts-de-instalación)
- [Consultas Comunes](#-consultas-comunes)
- [Mantenimiento y Monitoreo](#-mantenimiento-y-monitoreo)

## 🏗️ Arquitectura de Base de Datos

### Tecnología Base
- **Motor**: PostgreSQL 15+ (Supabase)
- **Extensiones**: PostGIS (para datos geoespaciales), UUID-OSSP
- **Autenticación**: Supabase Auth integrada
- **Tiempo Real**: Supabase Realtime para sincronización
- **Seguridad**: Row Level Security (RLS) habilitado

### Principios de Diseño

1. **Normalización**: Base de datos normalizada hasta 3FN
2. **Integridad Referencial**: Claves foráneas con constraints
3. **Seguridad por Filas**: RLS para isolación de datos por equipo
4. **Auditabilidad**: Timestamps de creación y actualización
5. **Escalabilidad**: Índices optimizados para consultas frecuentes

## 📊 Esquema Relacional

### Diagrama de Entidad-Relación

![Diagrama de Entidad-Relación - TopoTracker](./docs/images/database-erd.png)

*Diagrama completo del esquema de base de datos mostrando las relaciones entre todas las tablas del sistema TopoTracker.*

## 📚 Diccionario de Datos

### Tabla: `user_profiles`

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PRIMARY KEY, NOT NULL, FK → auth.users(id) | Identificador único del usuario, vinculado con Supabase Auth |
| `email` | TEXT | NOT NULL | Correo electrónico del usuario |
| `full_name` | TEXT | NULL | Nombre completo del usuario |
| `role` | TEXT | DEFAULT 'topografo', CHECK (role IN ('admin', 'topografo')) | Rol del usuario en el sistema |
| `team_id` | UUID | NULL, FK → teams(id) | Equipo al que pertenece el usuario |
| `is_active` | BOOLEAN | DEFAULT true | Estado activo/inactivo del usuario |
| `avatar_url` | TEXT | NULL | URL del avatar del usuario |
| `created_at` | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | Fecha y hora de creación del perfil |
| `updated_at` | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | Fecha y hora de última actualización |

**Índices:**
- `PRIMARY KEY (id)`
- `INDEX idx_user_profiles_team_active (team_id, is_active)`
- `INDEX idx_user_profiles_email (email)`

**Constraints:**
- `CHECK (role IN ('admin', 'topografo'))`
- `FOREIGN KEY (id) REFERENCES auth.users(id)`
- `FOREIGN KEY (team_id) REFERENCES teams(id)`

### Tabla: `teams`

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Identificador único del equipo |
| `name` | TEXT | NOT NULL | Nombre del equipo |
| `description` | TEXT | NULL | Descripción del equipo |
| `leader_id` | UUID | NULL, FK → user_profiles(id) | Líder del equipo |
| `users_id` | UUID[] | DEFAULT array[]::UUID[] | Array de IDs de usuarios miembros |
| `is_active` | BOOLEAN | DEFAULT true | Estado activo/inactivo del equipo |
| `created_at` | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | Fecha y hora de creación |
| `updated_at` | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | Fecha y hora de última actualización |

**Índices:**
- `PRIMARY KEY (id)`
- `INDEX idx_teams_active (is_active)`
- `INDEX idx_teams_leader (leader_id)`
- `GIN INDEX idx_teams_users_id (users_id)` // Para búsquedas en array

**Constraints:**
- `FOREIGN KEY (leader_id) REFERENCES user_profiles(id)`

### Tabla: `user_locations`

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Identificador único de la ubicación |
| `user_id` | UUID | NOT NULL, FK → user_profiles(id) | Usuario propietario de la ubicación |
| `latitude` | DECIMAL(10, 8) | NOT NULL | Latitud GPS (±90.00000000) |
| `longitude` | DECIMAL(11, 8) | NOT NULL | Longitud GPS (±180.00000000) |
| `altitude` | DECIMAL(8, 3) | NULL | Altitud en metros |
| `accuracy` | DECIMAL(8, 3) | NULL | Precisión del GPS en metros |
| `heading` | DECIMAL(6, 3) | NULL | Dirección en grados (0-360) |
| `speed` | DECIMAL(8, 3) | NULL | Velocidad en metros por segundo |
| `collaborative_session_id` | UUID | NULL, FK → collaborative_sessions(id) | Sesión colaborativa asociada |
| `timestamp` | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | Marca de tiempo de la ubicación |
| `is_active` | BOOLEAN | DEFAULT true | Indica si es la ubicación actual activa |

**Índices:**
- `PRIMARY KEY (id)`
- `INDEX idx_user_locations_user_active (user_id, is_active)`
- `INDEX idx_user_locations_timestamp (timestamp DESC)`
- `INDEX idx_user_locations_session (collaborative_session_id)`
- `SPATIAL INDEX idx_user_locations_coords (latitude, longitude)` // Para consultas geoespaciales

**Constraints:**
- `FOREIGN KEY (user_id) REFERENCES user_profiles(id)`
- `FOREIGN KEY (collaborative_session_id) REFERENCES collaborative_sessions(id)`
- `CHECK (latitude BETWEEN -90 AND 90)`
- `CHECK (longitude BETWEEN -180 AND 180)`
- `CHECK (heading IS NULL OR (heading >= 0 AND heading <= 360))`
- `CHECK (accuracy IS NULL OR accuracy >= 0)`
- `CHECK (speed IS NULL OR speed >= 0)`

### Tabla: `terrains`

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Identificador único del terreno |
| `name` | TEXT | NOT NULL | Nombre del terreno |
| `description` | TEXT | NULL | Descripción del terreno |
| `points` | JSONB | NOT NULL | Array de puntos del polígono del terreno |
| `area` | DECIMAL(15, 6) | NOT NULL | Área calculada en metros cuadrados |
| `user_id` | UUID | NOT NULL, FK → user_profiles(id) | Usuario creador del terreno |
| `team_id` | UUID | NULL, FK → teams(id) | Equipo al que pertenece el terreno |
| `created_at` | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | Fecha y hora de creación |
| `updated_at` | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | Fecha y hora de última actualización |
| `is_active` | BOOLEAN | DEFAULT true | Estado activo/inactivo del terreno |

**Estructura del campo `points` (JSONB):**
```json
[
  {
    "latitude": -33.4569,
    "longitude": -70.6483,
    "altitude": 547.2,
    "timestamp": "2024-01-15T10:30:00Z"
  },
  {
    "latitude": -33.4570,
    "longitude": -70.6484,
    "altitude": 548.1,
    "timestamp": "2024-01-15T10:30:15Z"
  }
]
```

**Índices:**
- `PRIMARY KEY (id)`
- `INDEX idx_terrains_user_active (user_id, is_active)`
- `INDEX idx_terrains_team (team_id)`
- `GIN INDEX idx_terrains_points (points)` // Para consultas en JSONB

**Constraints:**
- `FOREIGN KEY (user_id) REFERENCES user_profiles(id)`
- `FOREIGN KEY (team_id) REFERENCES teams(id)`
- `CHECK (area >= 0)`
- `CHECK (jsonb_array_length(points) >= 3)` // Mínimo 3 puntos para polígono

### Tabla: `collaborative_sessions`

| Campo | Tipo | Restricciones | Descripción |
|-------|------|---------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Identificador único de la sesión |
| `name` | TEXT | NOT NULL | Nombre de la sesión colaborativa |
| `description` | TEXT | NULL | Descripción de la sesión |
| `team_id` | UUID | NOT NULL, FK → teams(id) | Equipo asociado a la sesión |
| `created_by` | UUID | NOT NULL, FK → user_profiles(id) | Usuario creador de la sesión |
| `participants` | UUID[] | DEFAULT array[]::UUID[] | Array de IDs de participantes |
| `is_active` | BOOLEAN | DEFAULT true | Estado activo/inactivo de la sesión |
| `created_at` | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | Fecha y hora de creación |
| `updated_at` | TIMESTAMP WITH TIME ZONE | DEFAULT NOW() | Fecha y hora de última actualización |

**Índices:**
- `PRIMARY KEY (id)`
- `INDEX idx_collaborative_sessions_team_active (team_id, is_active)`
- `INDEX idx_collaborative_sessions_creator (created_by)`
- `GIN INDEX idx_collaborative_sessions_participants (participants)`

**Constraints:**
- `FOREIGN KEY (team_id) REFERENCES teams(id)`
- `FOREIGN KEY (created_by) REFERENCES user_profiles(id)`
- `UNIQUE (team_id) WHERE is_active = true` // Solo una sesión activa por equipo

## 🔧 Funciones y Procedimientos

### Función: `handle_new_user()`

**Propósito**: Crear automáticamente un perfil de usuario cuando se registra en Supabase Auth.

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

**Parámetros**: Ninguno (trigger automático)
**Retorna**: NEW record
**Uso**: Se ejecuta automáticamente al insertar en `auth.users`

### Función: `update_updated_at_column()`

**Propósito**: Actualizar automáticamente el campo `updated_at` en todas las tablas.

```sql
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

**Parámetros**: Ninguno (trigger automático)
**Retorna**: NEW record
**Uso**: Se ejecuta antes de cada UPDATE en tablas con `updated_at`

### Función: `create_collaborative_session()`

**Propósito**: Crear una sesión colaborativa con validaciones de negocio.

```sql
CREATE OR REPLACE FUNCTION public.create_collaborative_session(
    session_name TEXT,
    session_description TEXT,
    team_uuid UUID
)
RETURNS UUID
SECURITY DEFINER
AS $$
DECLARE
    new_session_id UUID;
    user_uuid UUID;
BEGIN
    -- Obtener el ID del usuario actual
    user_uuid := auth.uid();
    
    -- Verificar que el usuario pertenece al equipo
    IF NOT EXISTS (
        SELECT 1 FROM public.teams t 
        WHERE t.id = team_uuid 
        AND user_uuid = ANY(t.users_id) 
        AND t.is_active = true
    ) THEN
        RAISE EXCEPTION 'Usuario no pertenece al equipo especificado';
    END IF;
    
    -- Verificar que no hay otra sesión activa para el equipo
    IF EXISTS (
        SELECT 1 FROM public.collaborative_sessions 
        WHERE team_id = team_uuid AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Ya existe una sesión colaborativa activa para este equipo';
    END IF;
    
    -- Crear la nueva sesión
    INSERT INTO public.collaborative_sessions (
        name, description, team_id, created_by, participants
    ) VALUES (
        session_name, session_description, team_uuid, user_uuid, array[user_uuid]
    ) RETURNING id INTO new_session_id;
    
    RETURN new_session_id;
END;
$$ LANGUAGE plpgsql;
```

**Parámetros**:
- `session_name`: Nombre de la sesión
- `session_description`: Descripción de la sesión
- `team_uuid`: ID del equipo

**Retorna**: UUID de la sesión creada
**Excepciones**: 
- Usuario no pertenece al equipo
- Ya existe sesión activa para el equipo

### Función: `get_team_collaborative_sessions()`

**Propósito**: Obtener sesiones colaborativas de un equipo con información enriquecida.

```sql
CREATE OR REPLACE FUNCTION public.get_team_collaborative_sessions(
    user_uuid UUID
)
RETURNS TABLE (
    session_id UUID,
    session_name TEXT,
    session_description TEXT,
    team_id UUID,
    team_name TEXT,
    created_by UUID,
    creator_name TEXT,
    participants UUID[],
    participant_count INTEGER,
    is_participant BOOLEAN,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
)
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cs.id as session_id,
        cs.name as session_name,
        cs.description as session_description,
        cs.team_id,
        t.name as team_name,
        cs.created_by,
        up.full_name as creator_name,
        cs.participants,
        array_length(cs.participants, 1) as participant_count,
        user_uuid = ANY(cs.participants) as is_participant,
        cs.is_active,
        cs.created_at,
        cs.updated_at
    FROM public.collaborative_sessions cs
    INNER JOIN public.teams t ON cs.team_id = t.id
    INNER JOIN public.user_profiles up ON cs.created_by = up.id
    WHERE cs.is_active = true
    AND t.is_active = true
    AND user_uuid = ANY(t.users_id)
    ORDER BY cs.created_at DESC;
END;
$$ LANGUAGE plpgsql;
```

**Parámetros**:
- `user_uuid`: ID del usuario solicitante

**Retorna**: Tabla con información de sesiones
**Campos retornados**: Todos los datos de sesión con información enriquecida

### Función: `end_collaborative_session()`

**Propósito**: Finalizar una sesión colaborativa con validaciones.

```sql
CREATE OR REPLACE FUNCTION public.end_collaborative_session(
    session_uuid UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID;
BEGIN
    -- Obtener el ID del usuario actual
    user_uuid := auth.uid();
    
    -- Solo el creador puede finalizar la sesión
    UPDATE public.collaborative_sessions 
    SET is_active = false,
        updated_at = NOW()
    WHERE id = session_uuid 
    AND created_by = user_uuid
    AND is_active = true;
    
    -- Verificar si se actualizó alguna fila
    IF NOT FOUND THEN
        RETURN false;
    END IF;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;
```

**Parámetros**:
- `session_uuid`: ID de la sesión a finalizar

**Retorna**: Boolean indicando éxito/fallo
**Validaciones**: Solo el creador puede finalizar

### Funciones de Equipos

#### `get_user_profile_with_team()`
```sql
CREATE OR REPLACE FUNCTION public.get_user_profile_with_team(user_uuid UUID)
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    full_name TEXT,
    role TEXT,
    team_id UUID,
    team_name TEXT,
    team_description TEXT,
    is_leader BOOLEAN,
    member_count INTEGER
)
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.id as user_id,
        up.email,
        up.full_name,
        up.role,
        t.id as team_id,
        t.name as team_name,
        t.description as team_description,
        (t.leader_id = up.id) as is_leader,
        array_length(t.users_id, 1) as member_count
    FROM public.user_profiles up
    LEFT JOIN public.teams t ON up.team_id = t.id AND t.is_active = true
    WHERE up.id = user_uuid AND up.is_active = true;
END;
$$ LANGUAGE plpgsql;
```

#### `get_team_members()`
```sql
CREATE OR REPLACE FUNCTION public.get_team_members(team_uuid UUID)
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    full_name TEXT,
    role TEXT,
    is_leader BOOLEAN,
    avatar_url TEXT,
    is_active BOOLEAN
)
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.id as user_id,
        up.email,
        up.full_name,
        up.role,
        (t.leader_id = up.id) as is_leader,
        up.avatar_url,
        up.is_active
    FROM public.user_profiles up
    INNER JOIN public.teams t ON up.team_id = t.id
    WHERE t.id = team_uuid 
    AND t.is_active = true
    ORDER BY (t.leader_id = up.id) DESC, up.full_name;
END;
$$ LANGUAGE plpgsql;
```

## 🔒 Políticas de Seguridad (RLS)

### Políticas para `user_profiles`

#### 1. Ver propio perfil
```sql
CREATE POLICY "Los usuarios pueden ver su propio perfil" 
ON public.user_profiles FOR SELECT 
USING (auth.uid() = id);
```

#### 2. Actualizar propio perfil
```sql
CREATE POLICY "Los usuarios pueden actualizar su propio perfil" 
ON public.user_profiles FOR UPDATE 
USING (auth.uid() = id);
```

#### 3. Ver perfiles del mismo equipo
```sql
CREATE POLICY "Los usuarios pueden ver perfiles del mismo equipo" 
ON public.user_profiles FOR SELECT 
USING (
    team_id IN (
        SELECT team_id FROM public.user_profiles 
        WHERE id = auth.uid()
    )
);
```

### Políticas para `teams`

#### 1. Ver propio equipo
```sql
CREATE POLICY "Los miembros pueden ver su equipo" 
ON public.teams FOR SELECT 
USING (
    id IN (
        SELECT team_id FROM public.user_profiles 
        WHERE id = auth.uid()
    )
);
```

### Políticas para `user_locations`

#### 1. Insertar propia ubicación
```sql
CREATE POLICY "Los usuarios pueden insertar su propia ubicación" 
ON public.user_locations FOR INSERT 
WITH CHECK (auth.uid() = user_id);
```

#### 2. Ver ubicaciones del equipo
```sql
CREATE POLICY "Los usuarios pueden ver ubicaciones del mismo equipo" 
ON public.user_locations FOR SELECT 
USING (
    user_id IN (
        SELECT id FROM public.user_profiles 
        WHERE team_id = (
            SELECT team_id FROM public.user_profiles 
            WHERE id = auth.uid()
        )
    )
);
```

#### 3. Actualizar propia ubicación
```sql
CREATE POLICY "Los usuarios pueden actualizar su propia ubicación"
ON public.user_locations FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

#### 4. Ver propia ubicación
```sql
CREATE POLICY "Los usuarios pueden ver su propia ubicación"
ON public.user_locations FOR SELECT
USING (auth.uid() = user_id);
```

### Políticas para `terrains`

#### 1. Crear propios terrenos
```sql
CREATE POLICY "Los usuarios pueden crear sus propios terrenos" 
ON public.terrains FOR INSERT 
WITH CHECK (auth.uid() = user_id);
```

#### 2. Ver propios terrenos
```sql
CREATE POLICY "Los usuarios pueden ver sus propios terrenos" 
ON public.terrains FOR SELECT 
USING (auth.uid() = user_id);
```

#### 3. Ver terrenos del equipo
```sql
CREATE POLICY "Los usuarios pueden ver terrenos del mismo equipo" 
ON public.terrains FOR SELECT 
USING (
    team_id IN (
        SELECT team_id FROM public.user_profiles 
        WHERE id = auth.uid()
    )
);
```

#### 4. Actualizar propios terrenos
```sql
CREATE POLICY "Los usuarios pueden actualizar sus propios terrenos" 
ON public.terrains FOR UPDATE 
USING (auth.uid() = user_id);
```

#### 5. Solo usuarios activos pueden crear terrenos
```sql
CREATE POLICY "Solo usuarios activos pueden crear terrenos" 
ON public.terrains FOR INSERT 
WITH CHECK (
    auth.uid() = user_id AND 
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND is_active = true
    )
);
```

### Políticas para `collaborative_sessions`

#### 1. Ver sesiones del equipo
```sql
CREATE POLICY "Los miembros del equipo pueden ver sesiones" 
ON public.collaborative_sessions FOR SELECT 
USING (
    team_id IN (
        SELECT team_id FROM public.user_profiles 
        WHERE id = auth.uid()
    )
);
```

#### 2. Crear sesiones del equipo
```sql
CREATE POLICY "Los miembros del equipo pueden crear sesiones" 
ON public.collaborative_sessions FOR INSERT 
WITH CHECK (
    team_id IN (
        SELECT team_id FROM public.user_profiles 
        WHERE id = auth.uid()
    )
);
```

#### 3. Solo creador puede actualizar
```sql
CREATE POLICY "Solo el creador puede actualizar sesiones" 
ON public.collaborative_sessions FOR UPDATE 
USING (auth.uid() = created_by);
```

## 📈 Índices y Optimización

### Índices de Rendimiento Principal

#### 1. Ubicaciones activas por usuario
```sql
CREATE INDEX idx_user_locations_user_active 
ON public.user_locations(user_id, is_active) 
WHERE is_active = true;
```

#### 2. Terrenos por usuario activos
```sql
CREATE INDEX idx_terrains_user_active 
ON public.terrains(user_id, is_active) 
WHERE is_active = true;
```

#### 3. Sesiones colaborativas activas por equipo
```sql
CREATE INDEX idx_collaborative_sessions_team_active 
ON public.collaborative_sessions(team_id, is_active) 
WHERE is_active = true;
```

#### 4. Ubicaciones por timestamp (para historial)
```sql
CREATE INDEX idx_user_locations_timestamp 
ON public.user_locations(timestamp DESC);
```

#### 5. Usuarios por equipo
```sql
CREATE INDEX idx_user_profiles_team_active 
ON public.user_profiles(team_id, is_active) 
WHERE is_active = true;
```

### Índices para Arrays

#### 1. Miembros de equipos
```sql
CREATE INDEX idx_teams_users_id 
ON public.teams USING GIN(users_id);
```

#### 2. Participantes en sesiones
```sql
CREATE INDEX idx_collaborative_sessions_participants 
ON public.collaborative_sessions USING GIN(participants);
```

### Índices para JSONB

#### 1. Puntos de terrenos
```sql
CREATE INDEX idx_terrains_points 
ON public.terrains USING GIN(points);
```

#### 2. Búsqueda específica en puntos
```sql
CREATE INDEX idx_terrains_points_coordinates 
ON public.terrains USING GIN((points -> 'coordinates'));
```

### Índices Geoespaciales

#### 1. Coordenadas de ubicaciones
```sql
CREATE INDEX idx_user_locations_coordinates 
ON public.user_locations(latitude, longitude);
```

#### 2. Índice espacial con PostGIS (opcional)
```sql
-- Si se habilita PostGIS
CREATE INDEX idx_user_locations_point 
ON public.user_locations USING GIST(
    ST_Point(longitude, latitude)
);
```

## ⚡ Triggers y Automatización

### Trigger: Crear perfil automático
```sql
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### Triggers: Actualizar updated_at

#### 1. User Profiles
```sql
CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
```

#### 2. Teams
```sql
CREATE TRIGGER update_teams_updated_at
    BEFORE UPDATE ON public.teams
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
```

#### 3. Terrains
```sql
CREATE TRIGGER update_terrains_updated_at
    BEFORE UPDATE ON public.terrains
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
```

#### 4. Collaborative Sessions
```sql
CREATE TRIGGER update_collaborative_sessions_updated_at
    BEFORE UPDATE ON public.collaborative_sessions
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
```

### Trigger: Validación de sesiones únicas
```sql
CREATE OR REPLACE FUNCTION validate_unique_active_session()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_active = true AND EXISTS (
        SELECT 1 FROM public.collaborative_sessions 
        WHERE team_id = NEW.team_id 
        AND is_active = true 
        AND id != NEW.id
    ) THEN
        RAISE EXCEPTION 'Ya existe una sesión activa para este equipo';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_unique_active_session
    BEFORE INSERT OR UPDATE ON public.collaborative_sessions
    FOR EACH ROW EXECUTE FUNCTION validate_unique_active_session();
```

## 🚀 Scripts de Instalación

### Script 1: Limpieza y Configuración Base
**Archivo**: `setup.sql`
**Orden de ejecución**: 1

```sql
-- Eliminar elementos existentes
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
-- ... etc

-- Crear tablas en orden correcto
CREATE TABLE public.user_profiles (...);
CREATE TABLE public.teams (...);
CREATE TABLE public.user_locations (...);
CREATE TABLE public.terrains (...);

-- Configurar RLS y políticas básicas
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
-- ... etc
```

### Script 2: Sesiones Colaborativas
**Archivo**: `add_collaborative_sessions.sql`
**Orden de ejecución**: 2

```sql
-- Crear tabla de sesiones colaborativas
CREATE TABLE public.collaborative_sessions (...);

-- Agregar columna a user_locations
ALTER TABLE public.user_locations 
ADD COLUMN collaborative_session_id UUID;

-- Configurar políticas y funciones
```

### Script 3: Funciones de Equipos
**Archivo**: `funciones_Equipos.sql`
**Orden de ejecución**: 3

```sql
-- Funciones específicas para gestión de equipos
CREATE FUNCTION get_user_profile_with_team(...);
CREATE FUNCTION get_team_members(...);
-- ... etc
```

### Script 4: Terrenos (si es separado)
**Archivo**: `add_terrains_table.sql`
**Orden de ejecución**: 4 (opcional)

## 📝 Consultas Comunes

### 1. Obtener ubicaciones activas del equipo
```sql
SELECT 
    ul.*,
    up.full_name,
    up.role
FROM public.user_locations ul
INNER JOIN public.user_profiles up ON ul.user_id = up.id
WHERE ul.is_active = true
AND up.team_id = (
    SELECT team_id FROM public.user_profiles 
    WHERE id = auth.uid()
)
ORDER BY ul.timestamp DESC;
```

### 2. Estadísticas de terrenos por usuario
```sql
SELECT 
    COUNT(*) as total_terrains,
    SUM(area) as total_area,
    AVG(area) as avg_area,
    MAX(area) as max_area
FROM public.terrains
WHERE user_id = auth.uid()
AND is_active = true;
```

### 3. Historial de ubicaciones con filtro de tiempo
```sql
SELECT *
FROM public.user_locations
WHERE user_id = $1
AND timestamp >= $2
AND timestamp <= $3
ORDER BY timestamp DESC
LIMIT 1000;
```

### 4. Sesiones colaborativas activas con participantes
```sql
SELECT 
    cs.*,
    t.name as team_name,
    array_length(cs.participants, 1) as participant_count,
    creator.full_name as creator_name
FROM public.collaborative_sessions cs
INNER JOIN public.teams t ON cs.team_id = t.id
INNER JOIN public.user_profiles creator ON cs.created_by = creator.id
WHERE cs.is_active = true
AND cs.team_id = $1;
```

### 5. Métricas del sistema (para admin)
```sql
SELECT 
    'users' as metric,
    COUNT(*) as value
FROM public.user_profiles
WHERE is_active = true
UNION ALL
SELECT 
    'teams' as metric,
    COUNT(*) as value
FROM public.teams
WHERE is_active = true
UNION ALL
SELECT 
    'active_locations' as metric,
    COUNT(*) as value
FROM public.user_locations
WHERE is_active = true
UNION ALL
SELECT 
    'terrains' as metric,
    COUNT(*) as value
FROM public.terrains
WHERE is_active = true;
```

## 🔧 Mantenimiento y Monitoreo

### Consultas de Mantenimiento

#### 1. Limpiar ubicaciones antiguas
```sql
-- Eliminar ubicaciones inactivas más antiguas que 30 días
DELETE FROM public.user_locations
WHERE is_active = false
AND timestamp < NOW() - INTERVAL '30 days';
```

#### 2. Estadísticas de uso por tabla
```sql
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_rows,
    n_dead_tup as dead_rows
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_live_tup DESC;
```

#### 3. Tamaño de tablas
```sql
SELECT 
    table_name,
    pg_size_pretty(pg_total_relation_size('public.'||table_name)) as size
FROM information_schema.tables 
WHERE table_schema = 'public'
ORDER BY pg_total_relation_size('public.'||table_name) DESC;
```

### Monitoreo de Rendimiento

#### 1. Consultas lentas
```sql
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements
WHERE query LIKE '%public.%'
ORDER BY mean_time DESC
LIMIT 10;
```

#### 2. Uso de índices
```sql
SELECT 
    indexrelname as index_name,
    relname as table_name,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY idx_scan DESC;
```

### Respaldos y Archivado

#### 1. Comando de respaldo completo
```bash
pg_dump -h your-host -U postgres -d your-database -f backup_$(date +%Y%m%d).sql
```

#### 2. Respaldo solo de datos
```bash
pg_dump -h your-host -U postgres -d your-database --data-only -f data_backup_$(date +%Y%m%d).sql
```

#### 3. Respaldo de esquema solamente
```bash
pg_dump -h your-host -U postgres -d your-database --schema-only -f schema_backup_$(date +%Y%m%d).sql
```

### Alertas y Monitoreo

#### 1. Verificar conexiones activas
```sql
SELECT 
    state,
    COUNT(*) as connections
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state;
```

#### 2. Verificar bloqueos
```sql
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS current_statement_in_blocking_process
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.GRANTED;
```

---

**Versión de Base de Datos**: 1.0.0
**Compatible con**: PostgreSQL 13+, Supabase
**Última actualización**: Agosto 2025
