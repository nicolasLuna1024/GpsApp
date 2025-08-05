-- ===========================================
-- INSTRUCCIONES PARA CORREGIR LA BASE DE DATOS
-- Ejecutar estos comandos en: Dashboard Supabase → SQL Editor
-- ===========================================

-- IMPORTANTE: Ejecutar estos comandos en el orden indicado

-- 1. Primero, crear las funciones RPC para administradores
-- (Copiar y pegar desde admin_functions.sql)

-- 2. Agregar políticas adicionales para administradores si no existen
-- Verificar que existan estas políticas, si no, crearlas:

-- Política para que administradores puedan ver todos los perfiles
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_profiles' 
        AND policyname = 'Administradores pueden ver todos los perfiles'
    ) THEN
        CREATE POLICY "Administradores pueden ver todos los perfiles"
        ON public.user_profiles
        FOR SELECT
        USING (
            EXISTS (
                SELECT 1 FROM public.user_profiles up
                WHERE up.id = auth.uid() AND up.role = 'admin'
            )
        );
    END IF;
END
$$;

-- Política para que administradores puedan actualizar perfiles
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_profiles' 
        AND policyname = 'Administradores pueden actualizar perfiles'
    ) THEN
        CREATE POLICY "Administradores pueden actualizar perfiles"
        ON public.user_profiles
        FOR UPDATE
        USING (
            EXISTS (
                SELECT 1 FROM public.user_profiles up
                WHERE up.id = auth.uid() AND up.role = 'admin'
            )
        );
    END IF;
END
$$;

-- Política para que administradores puedan crear equipos
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'teams' 
        AND policyname = 'Administradores pueden crear equipos'
    ) THEN
        CREATE POLICY "Administradores pueden crear equipos"
        ON public.teams
        FOR INSERT
        WITH CHECK (
            EXISTS (
                SELECT 1 FROM public.user_profiles up
                WHERE up.id = auth.uid() AND up.role = 'admin'
            )
        );
    END IF;
END
$$;

-- Política para que administradores puedan ver todos los equipos
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'teams' 
        AND policyname = 'Administradores pueden ver todos los equipos'
    ) THEN
        CREATE POLICY "Administradores pueden ver todos los equipos"
        ON public.teams
        FOR SELECT
        USING (
            EXISTS (
                SELECT 1 FROM public.user_profiles up
                WHERE up.id = auth.uid() AND up.role = 'admin'
            )
        );
    END IF;
END
$$;

-- Política para que administradores puedan actualizar equipos
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'teams' 
        AND policyname = 'Administradores pueden actualizar equipos'
    ) THEN
        CREATE POLICY "Administradores pueden actualizar equipos"
        ON public.teams
        FOR UPDATE
        USING (
            EXISTS (
                SELECT 1 FROM public.user_profiles up
                WHERE up.id = auth.uid() AND up.role = 'admin'
            )
        );
    END IF;
END
$$;

-- 3. Crear índices para mejorar performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON public.user_profiles(role);
CREATE INDEX IF NOT EXISTS idx_user_profiles_active ON public.user_profiles(is_active);
CREATE INDEX IF NOT EXISTS idx_teams_leader ON public.teams(leader_id);
CREATE INDEX IF NOT EXISTS idx_teams_users_gin ON public.teams USING GIN(users_id);

-- 4. Verificar que el trigger para crear perfiles automáticamente funcione
-- Si hay problemas con la creación de usuarios, verificar esta función:

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name, role, is_active)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
        'topografo',
        true
    );
    RETURN NEW;
EXCEPTION WHEN others THEN
    -- Log del error pero no fallar la creación del usuario
    RAISE WARNING 'Error creando perfil para usuario %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recrear el trigger si es necesario
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. Función helper para verificar si un usuario es admin (útil para debugging)
CREATE OR REPLACE FUNCTION public.is_admin(user_id UUID DEFAULT auth.uid())
RETURNS BOOLEAN
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = user_id AND role = 'admin' AND is_active = true
    );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.is_admin(UUID) TO authenticated;

-- 6. Función para obtener equipos de un usuario (debugging)
CREATE OR REPLACE FUNCTION public.get_user_teams_debug(user_id UUID DEFAULT auth.uid())
RETURNS TABLE (
    team_id UUID,
    team_name TEXT,
    is_member BOOLEAN,
    is_leader BOOLEAN
)
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id as team_id,
        t.name as team_name,
        (user_id = ANY(t.users_id)) as is_member,
        (t.leader_id = user_id) as is_leader
    FROM public.teams t
    WHERE t.is_active = true
    AND (user_id = ANY(t.users_id) OR t.leader_id = user_id);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION public.get_user_teams_debug(UUID) TO authenticated;

-- 7. Verificación final: consulta para ver si todo está funcionando
-- Ejecutar esta consulta para verificar permisos y datos:

/*
-- Test query para verificar que todo funciona:
SELECT 
    'user_profiles' as tabla,
    COUNT(*) as total_registros
FROM public.user_profiles
UNION ALL
SELECT 
    'teams' as tabla,
    COUNT(*) as total_registros  
FROM public.teams
UNION ALL
SELECT 
    'admins' as tabla,
    COUNT(*) as total_registros
FROM public.user_profiles 
WHERE role = 'admin';
*/
