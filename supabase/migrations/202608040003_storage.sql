insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('package-images', 'package-images', true, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('vendor-documents', 'vendor-documents', false, 10485760, array['application/pdf', 'image/jpeg', 'image/png']),
  ('user-avatars', 'user-avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp']),
  ('delivery-proof', 'delivery-proof', false, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "public_read_package_images" on storage.objects for select using (bucket_id in ('package-images', 'user-avatars'));
create policy "authenticated_upload_avatars" on storage.objects for insert to authenticated with check (bucket_id = 'user-avatars' and owner = auth.uid());
create policy "admins_manage_storage" on storage.objects for all to authenticated using (public.is_admin()) with check (public.is_admin());
