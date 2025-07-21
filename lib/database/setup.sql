-- ===========================================
-- COMANDOS SQL PARA SUPABASE
-- Ejecutar en: Dashboard Supabase → SQL Editor
-- ===========================================

-- 1. Tabla de perfiles de usuario (extendiendo auth.users)
CREATE TABLE public.user_profiles (
    id UUID REFERENCES auth.users(id) PRIMARY KEY,
    email TEXT NOT NULL,
    full_name TEXT,
    role TEXT DEFAULT 'topografo' CHECK (role IN ('admin', 'topografo', 'supervisor')),
    team_id UUID,
    is_active BOOLEAN DEFAULT true,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Tabla de equipos/grupos de topógrafos
CREATE TABLE public.teams (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    leader_id UUID REFERENCES public.user_profiles(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Tabla de ubicaciones en tiempo real
CREATE TABLE public.user_locations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.user_profiles(id) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    altitude DECIMAL(8, 3),
    accuracy DECIMAL(8, 3),
    heading DECIMAL(6, 3),
    speed DECIMAL(8, 3),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- 4. Tabla de terrenos mapeados
CREATE TABLE public.terrains (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    points JSONB NOT NULL, -- Array de puntos {latitude, longitude, altitude, timestamp}
    area DECIMAL(15, 6) NOT NULL, -- Área en metros cuadrados
    user_id UUID REFERENCES public.user_profiles(id) NOT NULL,
    team_id UUID REFERENCES public.teams(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- 4. Agregar foreign key para team_id en user_profiles
ALTER TABLE public.user_profiles 
ADD CONSTRAINT fk_user_profiles_team 
FOREIGN KEY (team_id) REFERENCES public.teams(id);

-- 5. Agregar foreign key para team_id en terrains
ALTER TABLE public.terrains 
ADD CONSTRAINT fk_terrains_team 
FOREIGN KEY (team_id) REFERENCES public.teams(id);

-- ===========================================
-- ROW LEVEL SECURITY (RLS) - SEGURIDAD
-- ===========================================

-- Habilitar RLS en todas las tablas
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.terrains ENABLE ROW LEVEL SECURITY;

-- Políticas para user_profiles
CREATE POLICY "Los usuarios pueden ver su propio perfil" 
ON public.user_profiles FOR SELECT 
USING (auth.uid() = id);

CREATE POLICY "Los usuarios pueden actualizar su propio perfil" 
ON public.user_profiles FOR UPDATE 
USING (auth.uid() = id);

CREATE POLICY "Los usuarios pueden ver perfiles del mismo equipo" 
ON public.user_profiles FOR SELECT 
USING (
    team_id IN (
        SELECT team_id FROM public.user_profiles 
        WHERE id = auth.uid()
    )
);

-- Políticas para teams
CREATE POLICY "Los miembros pueden ver su equipo" 
ON public.teams FOR SELECT 
USING (
    id IN (
        SELECT team_id FROM public.user_profiles 
        WHERE id = auth.uid()
    )
);

-- Políticas para user_locations
CREATE POLICY "Los usuarios pueden insertar su propia ubicación" 
ON public.user_locations FOR INSERT 
WITH CHECK (auth.uid() = user_id);

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

-- Políticas para terrains
CREATE POLICY "Los usuarios pueden crear sus propios terrenos" 
ON public.terrains FOR INSERT 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Los usuarios pueden ver sus propios terrenos" 
ON public.terrains FOR SELECT 
USING (auth.uid() = user_id);

CREATE POLICY "Los usuarios pueden ver terrenos del mismo equipo" 
ON public.terrains FOR SELECT 
USING (
    team_id IN (
        SELECT team_id FROM public.user_profiles 
        WHERE id = auth.uid()
    )
);

CREATE POLICY "Los usuarios pueden actualizar sus propios terrenos" 
ON public.terrains FOR UPDATE 
USING (auth.uid() = user_id);

-- ===========================================
-- FUNCIONES Y TRIGGERS
-- ===========================================

-- Función para crear perfil automáticamente al registrarse
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name)
    VALUES (NEW.id, NEW.email, NEW.raw_user_meta_data->>'full_name');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para ejecutar la función
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Función para actualizar timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para updated_at
CREATE TRIGGER update_user_profiles_updated_at 
    BEFORE UPDATE ON public.user_profiles 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_teams_updated_at 
    BEFORE UPDATE ON public.teams 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_terrains_updated_at 
    BEFORE UPDATE ON public.terrains 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- ===========================================
-- POLÍTICAS ADICIONALES DE SEGURIDAD
-- ===========================================

-- Política adicional: Solo usuarios activos pueden acceder a sus datos
CREATE POLICY "Solo usuarios activos pueden acceder a user_profiles" 
ON public.user_profiles FOR ALL 
USING (
    auth.uid() = id AND is_active = true
);

-- Política adicional: Solo usuarios activos pueden insertar ubicaciones
CREATE POLICY "Solo usuarios activos pueden insertar ubicaciones" 
ON public.user_locations FOR INSERT 
WITH CHECK (
    auth.uid() = user_id AND 
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND is_active = true
    )
);

-- Política adicional: Solo usuarios activos pueden crear terrenos
CREATE POLICY "Solo usuarios activos pueden crear terrenos" 
ON public.terrains FOR INSERT 
WITH CHECK (
    auth.uid() = user_id AND 
    EXISTS (
        SELECT 1 FROM public.user_profiles 
        WHERE id = auth.uid() AND is_active = true
    )
);

-- ===========================================
-- DATOS DE PRUEBA (OPCIONAL)
-- ===========================================

-- Crear un equipo de ejemplo
INSERT INTO public.teams (name, description) 
VALUES ('Equipo Topografía Norte', 'Equipo encargado de la zona norte de la ciudad');

-- NOTA: Los usuarios se crearán automáticamente cuando se registren
-- a través de la aplicación Flutter
