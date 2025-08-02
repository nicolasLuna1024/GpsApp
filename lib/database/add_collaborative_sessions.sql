-- ===========================================
-- SCRIPT PARA AGREGAR SESIONES COLABORATIVAS
-- Ejecutar DESPUÉS del script de cleanup_and_setup.sql
-- ===========================================

-- 5. Tabla de sesiones colaborativas (si no existe)
CREATE TABLE IF NOT EXISTS public.collaborative_sessions (
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

-- Agregar columna de sesión colaborativa a user_locations (si no existe)
ALTER TABLE public.user_locations 
ADD COLUMN IF NOT EXISTS collaborative_session_id UUID 
REFERENCES public.collaborative_sessions(id);

-- Habilitar RLS para collaborative_sessions
ALTER TABLE public.collaborative_sessions ENABLE ROW LEVEL SECURITY;

-- Políticas para collaborative_sessions
CREATE POLICY "Users can create sessions for their teams" 
ON public.collaborative_sessions FOR INSERT 
WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Team members can view team sessions" 
ON public.collaborative_sessions FOR SELECT 
USING (
    auth.uid() IN (
        SELECT unnest(t.users_id) 
        FROM public.teams t 
        WHERE t.id = team_id AND t.is_active = true
    )
);

CREATE POLICY "Session creator can update session" 
ON public.collaborative_sessions FOR UPDATE 
USING (auth.uid() = created_by);

-- Trigger para updated_at
CREATE TRIGGER update_sessions_updated_at 
    BEFORE UPDATE ON public.collaborative_sessions 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===========================================
-- FUNCIONES PARA SESIONES COLABORATIVAS
-- ===========================================

-- Función para crear una sesión colaborativa
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

-- Función para unirse a una sesión colaborativa
CREATE OR REPLACE FUNCTION public.join_collaborative_session(
    session_uuid UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID;
    session_team_id UUID;
BEGIN
    -- Obtener el ID del usuario actual
    user_uuid := auth.uid();
    
    -- Obtener el team_id de la sesión
    SELECT team_id INTO session_team_id 
    FROM public.collaborative_sessions 
    WHERE id = session_uuid AND is_active = true;
    
    IF session_team_id IS NULL THEN
        RAISE EXCEPTION 'Sesión no encontrada o inactiva';
    END IF;
    
    -- Verificar que el usuario pertenece al equipo
    IF NOT EXISTS (
        SELECT 1 FROM public.teams t 
        WHERE t.id = session_team_id 
        AND user_uuid = ANY(t.users_id) 
        AND t.is_active = true
    ) THEN
        RAISE EXCEPTION 'Usuario no pertenece al equipo de esta sesión';
    END IF;
    
    -- Verificar que el usuario no está ya en otra sesión activa
    IF EXISTS (
        SELECT 1 FROM public.collaborative_sessions cs
        INNER JOIN public.teams t ON cs.team_id = t.id
        WHERE cs.id != session_uuid 
        AND cs.is_active = true 
        AND user_uuid = ANY(cs.participants)
        AND user_uuid = ANY(t.users_id)
    ) THEN
        RAISE EXCEPTION 'Usuario ya está participando en otra sesión colaborativa';
    END IF;
    
    -- Agregar el usuario a los participantes si no está ya
    UPDATE public.collaborative_sessions 
    SET participants = array_append(participants, user_uuid),
        updated_at = NOW()
    WHERE id = session_uuid 
    AND NOT (user_uuid = ANY(participants));
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener sesiones activas de los equipos del usuario
CREATE OR REPLACE FUNCTION public.get_user_team_sessions()
RETURNS TABLE (
    session_id UUID,
    session_name TEXT,
    session_description TEXT,
    team_id UUID,
    team_name TEXT,
    created_by UUID,
    creator_name TEXT,
    participant_count INTEGER,
    is_participant BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) 
SECURITY DEFINER
AS $$
DECLARE
    user_uuid UUID;
BEGIN
    -- Obtener el ID del usuario actual
    user_uuid := auth.uid();
    
    RETURN QUERY
    SELECT 
        cs.id as session_id,
        cs.name as session_name,
        cs.description as session_description,
        cs.team_id,
        t.name as team_name,
        cs.created_by,
        up.full_name as creator_name,
        array_length(cs.participants, 1) as participant_count,
        (user_uuid = ANY(cs.participants)) as is_participant,
        cs.created_at,
        cs.updated_at
    FROM public.collaborative_sessions cs
    INNER JOIN public.teams t ON cs.team_id = t.id
    INNER JOIN public.user_profiles up ON cs.created_by = up.id
    WHERE cs.is_active = true
    AND t.is_active = true
    AND user_uuid = ANY(t.users_id)  -- Usuario pertenece al equipo
    ORDER BY cs.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para finalizar una sesión colaborativa
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
        RAISE EXCEPTION 'Sesión no encontrada o usuario no autorizado';
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- PERMISOS PARA FUNCIONES
-- ===========================================

-- Permisos para funciones de sesiones colaborativas
GRANT EXECUTE ON FUNCTION public.create_collaborative_session(TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_collaborative_session(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_team_sessions() TO authenticated;
GRANT EXECUTE ON FUNCTION public.end_collaborative_session(UUID) TO authenticated;
