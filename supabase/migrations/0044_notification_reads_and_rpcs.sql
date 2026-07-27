-- ── Migration 0044: Notification Reads & Server-Side Read State RPCs ──────

-- 1. Create notification_reads table
CREATE TABLE IF NOT EXISTS public.notification_reads (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID REFERENCES auth.users NOT NULL,
  notification_id UUID REFERENCES public.notifications(id) ON DELETE CASCADE NOT NULL,
  read_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT notification_reads_user_notification_key UNIQUE(user_id, notification_id)
);

-- Enable RLS
ALTER TABLE public.notification_reads ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can read, insert, delete only their own rows
CREATE POLICY "notification_reads_select" ON public.notification_reads
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "notification_reads_insert" ON public.notification_reads
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "notification_reads_delete" ON public.notification_reads
  FOR DELETE USING (auth.uid() = user_id);

-- 2. RPC: mark_notification_read
CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  INSERT INTO public.notification_reads (user_id, notification_id)
  VALUES (auth.uid(), p_notification_id)
  ON CONFLICT (user_id, notification_id) DO NOTHING;
END;
$$;

-- 3. RPC: mark_all_notifications_read
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inserted INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN 0;
  END IF;

  WITH to_insert AS (
    SELECT n.id AS notification_id
    FROM public.notifications n
    WHERE (n.target_user_id IS NULL OR n.target_user_id = auth.uid())
      AND NOT EXISTS (
        SELECT 1 FROM public.notification_reads nr
        WHERE nr.user_id = auth.uid() AND nr.notification_id = n.id
      )
  ),
  inserted AS (
    INSERT INTO public.notification_reads (user_id, notification_id)
    SELECT auth.uid(), ti.notification_id FROM to_insert ti
    ON CONFLICT (user_id, notification_id) DO NOTHING
    RETURNING id
  )
  SELECT COUNT(*)::INT INTO v_inserted FROM inserted;

  RETURN v_inserted;
END;
$$;

-- 4. RPC: get_unread_notification_count
CREATE OR REPLACE FUNCTION public.get_unread_notification_count()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN 0;
  END IF;

  SELECT COUNT(*)::INT INTO v_count
  FROM public.notifications n
  WHERE (n.target_user_id IS NULL OR n.target_user_id = auth.uid())
    AND NOT EXISTS (
      SELECT 1 FROM public.notification_reads nr
      WHERE nr.user_id = auth.uid() AND nr.notification_id = n.id
    );

  RETURN v_count;
END;
$$;

-- 5. RPC: get_my_read_notification_ids
CREATE OR REPLACE FUNCTION public.get_my_read_notification_ids()
RETURNS TABLE (notification_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT nr.notification_id
  FROM public.notification_reads nr
  WHERE nr.user_id = auth.uid();
END;
$$;
