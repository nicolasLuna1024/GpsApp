-- Función para obtener perfil de usuario con equipo
CREATE OR REPLACE FUNCTION public.get_user_profile_with_team(user_uuid UUID)
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    full_name TEXT,
    role TEXT,
    team_id UUID,
    team_name TEXT,
    role_in_team TEXT,
    is_active BOOLEAN,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE
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
        up.team_id,
        t.name as team_name,
        up.role as role_in_team, -- Usar el rol del usuario como rol en el equipo
        up.is_active,
        up.avatar_url,
        up.created_at,
        up.updated_at
    FROM public.user_profiles up
    LEFT JOIN public.teams t ON up.team_id = t.id
    WHERE up.id = user_uuid
    AND up.is_active = true
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener equipos de un usuario (solo su equipo asignado)
CREATE OR REPLACE FUNCTION public.get_user_teams(user_uuid UUID)
RETURNS TABLE (
    team_id UUID,
    team_name TEXT,
    team_description TEXT,
    role_in_team TEXT,
    is_leader BOOLEAN,
    member_count BIGINT,
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
        up.role as role_in_team,
        (t.leader_id = user_uuid) as is_leader,
        (
            SELECT COUNT(*)
            FROM public.user_profiles up2
            WHERE up2.team_id = t.id
            AND up2.is_active = true
        ) as member_count,
        t.created_at,
        t.updated_at
    FROM public.user_profiles up
    INNER JOIN public.teams t ON up.team_id = t.id
    WHERE up.id = user_uuid
    AND up.is_active = true
    AND t.is_active = true
    ORDER BY t.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener miembros de un equipo
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
        up.role as role_in_team, -- Usar el rol del usuario como rol en el equipo
        up.avatar_url,
        up.created_at as joined_at
    FROM public.user_profiles up
    WHERE up.team_id = team_uuid
    AND up.is_active = true
    ORDER BY 
        CASE up.role
            WHEN 'admin' THEN 1 
            WHEN 'topografo' THEN 2 
            ELSE 3 
        END,
        up.full_name;
END;
$$ LANGUAGE plpgsql;

-- Función adicional para obtener información completa de un equipo específico
CREATE OR REPLACE FUNCTION public.get_team_info(team_uuid UUID)
RETURNS TABLE (
    team_id UUID,
    team_name TEXT,
    team_description TEXT,
    leader_id UUID,
    leader_name TEXT,
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
        up_leader.full_name as leader_name,
        (
            SELECT COUNT(*)
            FROM public.user_profiles up2
            WHERE up2.team_id = t.id
            AND up2.is_active = true
        ) as member_count,
        t.is_active,
        t.created_at,
        t.updated_at
    FROM public.teams t
    LEFT JOIN public.user_profiles up_leader ON t.leader_id = up_leader.id
    WHERE t.id = team_uuid
    AND t.is_active = true
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

