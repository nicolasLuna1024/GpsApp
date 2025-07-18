-- ===========================================
-- ACTUALIZACIÓN: AGREGAR TABLA DE TERRENOS
-- Ejecutar en: Dashboard Supabase → SQL Editor
-- ===========================================

-- Crear tabla de terrenos
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

-- Habilitar RLS
ALTER TABLE public.terrains ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad para terrains
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

-- Trigger para updated_at
CREATE TRIGGER update_terrains_updated_at 
    BEFORE UPDATE ON public.terrains 
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Foreign key constraint
ALTER TABLE public.terrains 
ADD CONSTRAINT fk_terrains_team 
FOREIGN KEY (team_id) REFERENCES public.teams(id);
