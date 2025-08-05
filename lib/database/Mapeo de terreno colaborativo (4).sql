CREATE TABLE IF NOT EXISTS public.collaborative_terrain_points (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    collaborative_session_id UUID REFERENCES public.collaborative_sessions(id) NOT NULL,
    user_id UUID REFERENCES public.user_profiles(id) NOT NULL,
    point_number INTEGER NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    altitude DECIMAL(8, 3),
    accuracy DECIMAL(8, 3),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Agregar columna para asociar terrenos finalizados con sesiones colaborativas
ALTER TABLE public.terrains 
ADD COLUMN IF NOT EXISTS collaborative_session_id UUID 
REFERENCES public.collaborative_sessions(id);

-- Índices para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_collaborative_terrain_points_session 
ON public.collaborative_terrain_points(collaborative_session_id);

CREATE INDEX IF NOT EXISTS idx_collaborative_terrain_points_active 
ON public.collaborative_terrain_points(collaborative_session_id, is_active);















-- FUNCIONES PARA MAPEO COLABORATIVO


-- Función para agregar un punto al mapeo colaborativo
CREATE OR REPLACE FUNCTION public.add_collaborative_terrain_point(
    session_uuid UUID,
    point_lat DECIMAL(10, 8),
    point_lng DECIMAL(11, 8),
    point_alt DECIMAL(8, 3) DEFAULT NULL,
    point_accuracy DECIMAL(8, 3) DEFAULT NULL
)
RETURNS TABLE (
    point_id UUID,
    point_number INTEGER,
    total_points INTEGER
)
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID;
    next_point_num INTEGER;
    new_point_id UUID;
    total_count INTEGER;
BEGIN
    -- Obtener el ID del usuario actual
    user_uuid := auth.uid();
    
    -- Verificar que el usuario participa en la sesión
    IF NOT EXISTS (
        SELECT 1 FROM public.collaborative_sessions cs
        WHERE cs.id = session_uuid
        AND cs.is_active = true
        AND user_uuid = ANY(cs.participants)
    ) THEN
        RAISE EXCEPTION 'Usuario no está participando en esta sesión colaborativa';
    END IF;
    
    -- Obtener el siguiente número de punto
    SELECT COALESCE(MAX(ctp.point_number), 0) + 1 INTO next_point_num
    FROM public.collaborative_terrain_points ctp
    WHERE ctp.collaborative_session_id = session_uuid
    AND ctp.is_active = true;
    
    -- Insertar el nuevo punto
    INSERT INTO public.collaborative_terrain_points (
        collaborative_session_id,
        user_id,
        point_number,
        latitude,
        longitude,
        altitude,
        accuracy
    ) VALUES (
        session_uuid,
        user_uuid,
        next_point_num,
        point_lat,
        point_lng,
        point_alt,
        point_accuracy
    ) RETURNING id INTO new_point_id;
    
    -- Obtener el total de puntos activos
    SELECT COUNT(*) INTO total_count
    FROM public.collaborative_terrain_points ctp
    WHERE ctp.collaborative_session_id = session_uuid
    AND ctp.is_active = true;
    
    RETURN QUERY SELECT new_point_id, next_point_num, total_count;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener puntos de una sesión colaborativa
CREATE OR REPLACE FUNCTION public.get_collaborative_terrain_points(
    session_uuid UUID
)
RETURNS TABLE (
    point_id UUID,
    user_id UUID,
    user_full_name TEXT,
    point_number INTEGER,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    altitude DECIMAL(8, 3),
    accuracy DECIMAL(8, 3),
    created_at TIMESTAMP WITH TIME ZONE
)
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID;
BEGIN
    -- Obtener el ID del usuario actual
    user_uuid := auth.uid();
    
    -- Verificar que el usuario participa en la sesión
    IF NOT EXISTS (
        SELECT 1 FROM public.collaborative_sessions cs
        WHERE cs.id = session_uuid
        AND cs.is_active = true
        AND user_uuid = ANY(cs.participants)
    ) THEN
        RAISE EXCEPTION 'Usuario no está participando en esta sesión colaborativa';
    END IF;
    
    RETURN QUERY
    SELECT 
        ctp.id as point_id,
        ctp.user_id,
        COALESCE(up.full_name, up.email) as user_full_name,
        ctp.point_number,
        ctp.latitude,
        ctp.longitude,
        ctp.altitude,
        ctp.accuracy,
        ctp.created_at
    FROM public.collaborative_terrain_points ctp
    INNER JOIN public.user_profiles up ON ctp.user_id = up.id
    WHERE ctp.collaborative_session_id = session_uuid
    AND ctp.is_active = true
    ORDER BY ctp.point_number ASC;
END;
$$ LANGUAGE plpgsql;

-- Función para eliminar el último punto agregado por un usuario
CREATE OR REPLACE FUNCTION public.remove_last_collaborative_point(
    session_uuid UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID;
    point_to_remove UUID;
BEGIN
    -- Obtener el ID del usuario actual
    user_uuid := auth.uid();
    
    -- Verificar que el usuario participa en la sesión
    IF NOT EXISTS (
        SELECT 1 FROM public.collaborative_sessions cs
        WHERE cs.id = session_uuid
        AND cs.is_active = true
        AND user_uuid = ANY(cs.participants)
    ) THEN
        RAISE EXCEPTION 'Usuario no está participando en esta sesión colaborativa';
    END IF;
    
    -- Buscar el último punto creado por este usuario
    SELECT ctp.id INTO point_to_remove
    FROM public.collaborative_terrain_points ctp
    WHERE ctp.collaborative_session_id = session_uuid
    AND ctp.user_id = user_uuid
    AND ctp.is_active = true
    ORDER BY ctp.created_at DESC
    LIMIT 1;
    
    -- Si se encontró un punto, marcarlo como inactivo
    IF point_to_remove IS NOT NULL THEN
        UPDATE public.collaborative_terrain_points
        SET is_active = false
        WHERE id = point_to_remove;
        
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Función para limpiar todos los puntos de una sesión colaborativa
CREATE OR REPLACE FUNCTION public.clear_all_collaborative_points(
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
    
    -- Verificar que el usuario participa en la sesión
    IF NOT EXISTS (
        SELECT 1 FROM public.collaborative_sessions cs
        WHERE cs.id = session_uuid
        AND cs.is_active = true
        AND user_uuid = ANY(cs.participants)
    ) THEN
        RAISE EXCEPTION 'Usuario no está participando en esta sesión colaborativa';
    END IF;
    
    -- Marcar todos los puntos como inactivos
    UPDATE public.collaborative_terrain_points ctp
    SET is_active = false
    WHERE ctp.collaborative_session_id = session_uuid
    AND ctp.is_active = true;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Función para calcular área colaborativa en tiempo real
CREATE OR REPLACE FUNCTION public.calculate_collaborative_terrain_area(
    session_uuid UUID
)
RETURNS DECIMAL(15, 6)
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID;
    point_count INTEGER;
    calculated_area DECIMAL(15, 6) := 0;
    points_array JSONB;
BEGIN
    -- Obtener el ID del usuario actual
    user_uuid := auth.uid();
    
    -- Verificar que el usuario participa en la sesión
    IF NOT EXISTS (
        SELECT 1 FROM public.collaborative_sessions cs
        WHERE cs.id = session_uuid
        AND cs.is_active = true
        AND user_uuid = ANY(cs.participants)
    ) THEN
        RAISE EXCEPTION 'Usuario no está participando en esta sesión colaborativa';
    END IF;
    
    -- Contar puntos activos
    SELECT COUNT(*) INTO point_count
    FROM public.collaborative_terrain_points ctp
    WHERE ctp.collaborative_session_id = session_uuid
    AND ctp.is_active = true;
    
    -- Se necesitan al menos 3 puntos para calcular área
    IF point_count < 3 THEN
        RETURN 0;
    END IF;
    
    -- Obtener puntos ordenados como array JSONB
    SELECT json_agg(
        json_build_object(
            'latitude', ctp.latitude,
            'longitude', ctp.longitude,
            'altitude', COALESCE(ctp.altitude, 0)
        ) ORDER BY ctp.point_number
    )::JSONB INTO points_array
    FROM public.collaborative_terrain_points ctp
    WHERE ctp.collaborative_session_id = session_uuid
    AND ctp.is_active = true;
    
    -- Calcular área usando fórmula de Shoelace (simplificada para PostgreSQL)
    -- Nota: Esta es una aproximación. Para mayor precisión, usa ST_Area con PostGIS
    WITH polygon_points AS (
        SELECT 
            (value->>'latitude')::DECIMAL(10,8) AS lat,
            (value->>'longitude')::DECIMAL(11,8) AS lng,
            ROW_NUMBER() OVER() AS rn
        FROM jsonb_array_elements(points_array)
    ),
    area_calc AS (
        SELECT 
            SUM(
                (p1.lng * p2.lat - p2.lng * p1.lat) * 
                111320 * 111320 * COS(RADIANS((p1.lat + p2.lat) / 2))
            ) / 2 AS area_m2
        FROM polygon_points p1
        JOIN polygon_points p2 ON p2.rn = CASE 
            WHEN p1.rn = (SELECT MAX(rn) FROM polygon_points) THEN 1 
            ELSE p1.rn + 1 
        END
    )
    SELECT ABS(area_m2) INTO calculated_area FROM area_calc;
    
    RETURN COALESCE(calculated_area, 0);
END;
$$ LANGUAGE plpgsql;

-- Función para finalizar y guardar terreno colaborativo
CREATE OR REPLACE FUNCTION public.save_collaborative_terrain(
    session_uuid UUID,
    terrain_name TEXT,
    terrain_description TEXT DEFAULT NULL
)
RETURNS UUID
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID;
    team_uuid UUID;
    point_count INTEGER;
    calculated_area DECIMAL(15, 6);
    points_jsonb JSONB;
    new_terrain_id UUID;
BEGIN
    -- Obtener el ID del usuario actual
    user_uuid := auth.uid();
    
    -- Verificar que el usuario participa en la sesión y obtener team_id
    SELECT cs.team_id INTO team_uuid
    FROM public.collaborative_sessions cs
    WHERE cs.id = session_uuid
    AND cs.is_active = true
    AND user_uuid = ANY(cs.participants);
    
    IF team_uuid IS NULL THEN
        RAISE EXCEPTION 'Usuario no está participando en esta sesión colaborativa';
    END IF;
    
    -- Contar puntos activos
    SELECT COUNT(*) INTO point_count
    FROM public.collaborative_terrain_points ctp
    WHERE ctp.collaborative_session_id = session_uuid
    AND ctp.is_active = true;
    
    -- Se necesitan al menos 3 puntos
    IF point_count < 3 THEN
        RAISE EXCEPTION 'Se necesitan al menos 3 puntos para guardar el terreno';
    END IF;
    
    -- Calcular área
    SELECT public.calculate_collaborative_terrain_area(session_uuid) INTO calculated_area;
    
    -- Obtener puntos como JSONB ordenados
    SELECT json_agg(
        json_build_object(
            'latitude', ctp.latitude,
            'longitude', ctp.longitude,
            'altitude', COALESCE(ctp.altitude, 0),
            'accuracy', COALESCE(ctp.accuracy, 0),
            'timestamp', ctp.created_at,
            'user_id', ctp.user_id,
            'point_number', ctp.point_number
        ) ORDER BY ctp.point_number
    )::JSONB INTO points_jsonb
    FROM public.collaborative_terrain_points ctp
    WHERE ctp.collaborative_session_id = session_uuid
    AND ctp.is_active = true;
    
    -- Crear el terreno
    INSERT INTO public.terrains (
        name,
        description,
        points,
        area,
        user_id,
        team_id,
        collaborative_session_id
    ) VALUES (
        terrain_name,
        COALESCE(terrain_description, 'Terreno creado colaborativamente'),
        points_jsonb,
        calculated_area,
        user_uuid,
        team_uuid,
        session_uuid
    ) RETURNING id INTO new_terrain_id;
    
    -- Marcar puntos colaborativos como procesados (opcional)
    UPDATE public.collaborative_terrain_points ctp
    SET is_active = false
    WHERE ctp.collaborative_session_id = session_uuid;
    
    RETURN new_terrain_id;
END;
$$ LANGUAGE plpgsql;


GRANT EXECUTE ON FUNCTION public.add_collaborative_terrain_point(UUID, DECIMAL, DECIMAL, DECIMAL, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_collaborative_terrain_points(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_last_collaborative_point(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_all_collaborative_points(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.calculate_collaborative_terrain_area(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_collaborative_terrain(UUID, TEXT, TEXT) TO authenticated;

