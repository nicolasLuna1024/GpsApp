-- ===========================================
-- FUNCIONES PARA EQUIPOS
-- Estas funciones usan el array users_id en teams para soporte multi-equipo
-- ===========================================

-- Función para obtener equipos de un usuario (formato compatible con Team.fromJson)
-- CORREGIDA: Busca en el array users_id de teams
CREATE OR REPLACE FUNCTION public.get_user_teams(user_uuid UUID)
RETURNS TABLE (
    team_id UUID,
    team_name TEXT,
    team_description TEXT,
    leader_id UUID,
    role_in_team TEXT,
    is_leader BOOLEAN,
    member_count BIGINT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
) 
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as team_id,
        t.name as team_name,
        t.description as team_description,
        t.leader_id,
        up.role as role_in_team,
        (t.leader_id = user_uuid) as is_leader,
        (
            SELECT array_length(t.users_id, 1)::BIGINT
        ) as member_count,
        t.is_active,
        t.created_at,
        t.updated_at
    FROM public.teams t
    INNER JOIN public.user_profiles up ON up.id = user_uuid
    WHERE user_uuid = ANY(t.users_id)
    AND up.is_active = true
    AND t.is_active = true
    ORDER BY t.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener miembros de un equipo
-- CORREGIDA: Usa el array users_id
CREATE OR REPLACE FUNCTION public.get_team_members(team_uuid UUID)
RETURNS TABLE (
    user_id UUID,
    full_name TEXT,
    email TEXT,
    role TEXT,
    role_in_team TEXT,
    avatar_url TEXT,
    joined_at TIMESTAMP WITH TIME ZONE
) 
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        up.id as user_id,
        COALESCE(up.full_name, up.email) as full_name,
        up.email,
        up.role,
        up.role as role_in_team,
        up.avatar_url,
        up.created_at as joined_at
    FROM public.user_profiles up
    INNER JOIN public.teams t ON up.id = ANY(t.users_id)
    WHERE t.id = team_uuid
    AND up.is_active = true
    AND t.is_active = true
    ORDER BY 
        CASE up.role
            WHEN 'admin' THEN 1 
            WHEN 'topografo' THEN 2 
            ELSE 3 
        END,
        up.full_name NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- PERMISOS PARA FUNCIONES
-- ===========================================

-- Dar permisos de ejecución a usuarios autenticados
GRANT EXECUTE ON FUNCTION public.get_user_teams(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_team_members(UUID) TO authenticated;

