-- ROX Store — تحديث: صور المنتجات (حتى 80 صورة لكل منتج)
-- شغّله مرة وحدة من Supabase > SQL Editor. آمن للتشغيل أكثر من مرة، وما يغيّر منتجاتك ولا حسابك.

alter table public.products add column if not exists images jsonb not null default '[]';
do $c$ begin
  if not exists (select 1 from pg_constraint where conname = 'products_images_max') then
    alter table public.products add constraint products_images_max check (jsonb_typeof(images) = 'array' and jsonb_array_length(images) <= 80);
  end if;
end $c$;

-- ============ صور المنتجات (عامة للقراءة، والرفع والحذف للأدمن فقط) ============
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('products', 'products', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists product_images_read on storage.objects;
create policy product_images_read on storage.objects for select using (bucket_id = 'products');
drop policy if exists product_images_add on storage.objects;
create policy product_images_add on storage.objects for insert to authenticated with check (bucket_id = 'products' and public.is_admin());
drop policy if exists product_images_edit on storage.objects;
create policy product_images_edit on storage.objects for update to authenticated using (bucket_id = 'products' and public.is_admin());
drop policy if exists product_images_del on storage.objects;
create policy product_images_del on storage.objects for delete to authenticated using (bucket_id = 'products' and public.is_admin());

notify pgrst, 'reload schema';
select 'تم تحديث صور المنتجات' as result;
