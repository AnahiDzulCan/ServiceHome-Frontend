-- La política de insert contaba filas de la misma tabla y causaba recursión de RLS.
-- El límite de 20 documentos por técnico pasa a un trigger.
drop policy if exists techdocs_insert on public.technician_documents;

create policy techdocs_insert on public.technician_documents
  for insert to authenticated
  with check (
    tecnico_id = (select auth.uid())
    and (select public.my_role()) = 'tecnico'
    and storage_path like (select auth.uid())::text || '/%'
    and exists (select 1 from storage.objects o
                 where o.bucket_id = 'documentos-tecnicos' and o.name = storage_path)
  );

create or replace function public.validate_technician_document()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended('documentos:' || new.tecnico_id::text, 0));
  if (select count(*) from public.technician_documents where tecnico_id = new.tecnico_id) >= 20 then
    raise exception 'Alcanzaste el máximo de 20 documentos. Contacta al administrador';
  end if;
  return new;
end
$$;

revoke execute on function public.validate_technician_document() from public, anon, authenticated;

create trigger trg_validate_technician_document
  before insert on public.technician_documents
  for each row execute function public.validate_technician_document();
