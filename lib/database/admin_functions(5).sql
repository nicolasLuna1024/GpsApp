-- ===========================================
-- FUNCIONES RPC PARA ADMINISTRADORES
-- ===========================================

-- Función para que los administradores obtengan todos los usuarios
CREATE OR REPLACE FUNCTION public.get_all_users_as_admin()
RETURNS SETOF public.user_profiles
SECURITY DEFINER
AS $$
BEGIN
    -- Verificar que el usuario que ejecuta la función es admin
    IF NOT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin' AND user_profiles.is_active = true
    ) THEN
        RAISE EXCEPTION 'Acceso denegado: no eres administrador';
    END IF;

    -- Retornar todos los usuarios
    RETURN QUERY
    SELECT * FROM public.user_profiles
    ORDER BY created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para que los administradores obtengan estadísticas del sistema
CREATE OR REPLACE FUNCTION public.get_system_stats_as_admin()
RETURNS JSON
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    total_users_count INTEGER;
    active_users_count INTEGER;
    admins_count INTEGER;
    topografos_count INTEGER;
    locations_today_count INTEGER;
    teams_count INTEGER;
BEGIN
    -- Verificar que el usuario que ejecuta la función es admin
    IF NOT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Acceso denegado: no eres administrador';
    END IF;

    -- Contar usuarios totales
    SELECT COUNT(*) INTO total_users_count FROM public.user_profiles;

    -- Contar usuarios activos
    SELECT COUNT(*) INTO active_users_count 
    FROM public.user_profiles 
    WHERE is_active = true;

    -- Contar administradores
    SELECT COUNT(*) INTO admins_count 
    FROM public.user_profiles 
    WHERE role = 'admin';

    -- Contar topógrafos
    SELECT COUNT(*) INTO topografos_count 
    FROM public.user_profiles 
    WHERE role = 'topografo';

    -- Contar ubicaciones de hoy
    SELECT COUNT(*) INTO locations_today_count 
    FROM public.user_locations 
    WHERE DATE(timestamp) = CURRENT_DATE;

    -- Contar equipos activos
    SELECT COUNT(*) INTO teams_count 
    FROM public.teams 
    WHERE is_active = true;

    -- Crear objeto JSON con las estadísticas
    result := json_build_object(
        'total_users', total_users_count,
        'active_users', active_users_count,
        'admins', admins_count,
        'topografos', topografos_count,
        'locations_today', locations_today_count,
        'teams_count', teams_count
    );

    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Función para que los administradores obtengan todos los equipos con detalles
CREATE OR REPLACE FUNCTION public.get_all_teams_as_admin()
RETURNS TABLE (
    id UUID,
    name TEXT,
    description TEXT,
    leader_id UUID,
    users_id UUID[],
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    leader_name TEXT,
    member_count INTEGER
) 
SECURITY DEFINER
AS $$
BEGIN
    -- Verificar que el usuario que ejecuta la función es admin
    IF NOT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Acceso denegado: no eres administrador';
    END IF;

    -- Retornar todos los equipos con información del líder
    RETURN QUERY
    SELECT 
        t.id,
        t.name,
        t.description,
        t.leader_id,
        t.users_id,
        t.is_active,
        t.created_at,
        t.updated_at,
        up.full_name as leader_name,
        COALESCE(array_length(t.users_id, 1), 0) as member_count
    FROM public.teams t
    LEFT JOIN public.user_profiles up ON t.leader_id = up.id
    ORDER BY t.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para que los administradores obtengan usuarios activos para ser líderes
CREATE OR REPLACE FUNCTION public.get_available_leaders_as_admin()
RETURNS TABLE (
    id UUID,
    email TEXT,
    full_name TEXT,
    role TEXT,
    is_active BOOLEAN
) 
SECURITY DEFINER
AS $$
BEGIN
    -- Verificar que el usuario que ejecuta la función es admin
    IF NOT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Acceso denegado: no eres administrador';
    END IF;

    -- Retornar usuarios activos que pueden ser líderes
    RETURN QUERY
    SELECT 
        up.id,
        up.email,
        up.full_name,
        up.role,
        up.is_active
    FROM public.user_profiles up
    WHERE up.is_active = true
    ORDER BY up.full_name ASC;
END;
$$ LANGUAGE plpgsql;

-- Función para que los administradores obtengan ubicaciones activas
CREATE OR REPLACE FUNCTION public.get_active_locations_as_admin()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    altitude DECIMAL(8, 3),
    accuracy DECIMAL(8, 3),
    heading DECIMAL(6, 3),
    speed DECIMAL(8, 3),
    location_timestamp TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN,
    user_full_name TEXT,
    user_role TEXT
)
SECURITY DEFINER
AS $$
BEGIN
    -- Verificar que el usuario que ejecuta la función es admin
    IF NOT EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE user_profiles.id = auth.uid() AND user_profiles.role = 'admin'
    ) THEN
        RAISE EXCEPTION 'Acceso denegado: no eres administrador';
    END IF;

    -- Retornar ubicaciones activas con información del usuario
    RETURN QUERY
    SELECT 
        ul.id,
        ul.user_id,
        ul.latitude,
        ul.longitude,
        ul.altitude,
        ul.accuracy,
        ul.heading,
        ul.speed,
        ul.timestamp as location_timestamp,
        ul.is_active,
        up.full_name as user_full_name,
        up.role as user_role
    FROM public.user_locations ul
    INNER JOIN public.user_profiles up ON ul.user_id = up.id
    WHERE ul.is_active = true AND up.is_active = true
    ORDER BY ul.timestamp DESC;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- PERMISOS PARA FUNCIONES RPC
-- ===========================================

-- Dar permisos de ejecución a usuarios autenticados
GRANT EXECUTE ON FUNCTION public.get_all_users_as_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_system_stats_as_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_teams_as_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_leaders_as_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_locations_as_admin() TO authenticated;
