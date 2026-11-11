-- ROX Store — إعداد قاعدة البيانات والحماية على Supabase
-- شغّله من SQL Editor بعد ما تنشئ حسابك من Authentication > Users.
-- آمن للتشغيل أكثر من مرة.

create extension if not exists pgcrypto with schema extensions;

-- ============ الجداول ============
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  email text, name text default '', discord text default '', cfx text default '',
  created_at timestamptz not null default now()
);
create table if not exists public.admins (
  user_id uuid primary key references auth.users on delete cascade,
  pin_hash text, fails int not null default 0, locked_until timestamptz
);
create table if not exists public.admin_sessions (
  session_id text primary key, user_id uuid not null references auth.users on delete cascade, expires_at timestamptz not null
);
create table if not exists public.products (
  id text primary key, cat text not null, art text not null default '', name text not null, descr text not null default '',
  price numeric(10,2) not null check (price >= 0), old_price numeric(10,2), fw jsonb not null default '[]',
  h int not null default 0, tag text, is_new boolean not null default false, sort int not null default 0, active boolean not null default true
);
create table if not exists public.settings (
  id int primary key default 1 check (id = 1), data jsonb not null default '{}'
);
create table if not exists public.coupons (
  code text primary key, pct int not null check (pct between 1 and 90), active boolean not null default true
);
create table if not exists public.orders (
  id bigint generated always as identity (start with 1041) primary key,
  ref text unique not null, user_id uuid references auth.users on delete set null,
  cu text default '', cfx text default '', items jsonb not null default '[]',
  subtotal numeric(10,2) not null default 0, total numeric(10,2) not null default 0, coupon text, pct int,
  pay text not null default 'bank', status text not null default 'pending' check (status in ('pending','review','delivered','rejected','refunded')),
  receipt_path text, receipt_hash text, chk jsonb, note text default '',
  created_at timestamptz not null default now()
);
create index if not exists orders_user_idx on public.orders (user_id, created_at desc);
create table if not exists public.activity_log (
  id bigint generated always as identity primary key, at timestamptz not null default now(), msg text not null
);

-- ============ دوال الحماية ============
-- معرّف جلسة الدخول الحالية (من رمز الدخول)
create or replace function public.sid() returns text language sql stable as $$
  select coalesce(auth.jwt() ->> 'session_id', auth.uid()::text)
$$;

-- هل المستخدم الحالي أدمن؟ (الخطوة الأولى فقط)
create or replace function public.is_admin_user() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from admins where user_id = auth.uid())
$$;

-- هل هو أدمن وفتح القفل بكلمة المرور الثانية في هذي الجلسة؟ كل صلاحيات اللوحة تعتمد على هذي الدالة.
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from admins a join admin_sessions s on s.user_id = a.user_id
    where a.user_id = auth.uid() and s.session_id = public.sid() and s.expires_at > now())
$$;

create or replace function public.admin_state() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('admin', a.user_id is not null, 'has_pin', a.pin_hash is not null,
                            'unlocked', public.is_admin(), 'locked_until', a.locked_until)
  from (select 1) x left join admins a on a.user_id = auth.uid()
$$;

-- تسجيل كلمة المرور الثانية أول مرة، أو تغييرها بعد فتح القفل
create or replace function public.admin_set_pin(new_pin text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare h text;
begin
  if not public.is_admin_user() then raise exception 'not_allowed'; end if;
  select pin_hash into h from admins where user_id = auth.uid();
  if h is not null and not public.is_admin() then raise exception 'locked'; end if;
  if new_pin is null or length(new_pin) < 8 then raise exception 'short_pin'; end if;
  update admins set pin_hash = crypt(new_pin, gen_salt('bf', 10)), fails = 0, locked_until = null where user_id = auth.uid();
  insert into admin_sessions (session_id, user_id, expires_at) values (public.sid(), auth.uid(), now() + interval '12 hours')
    on conflict (session_id) do update set user_id = excluded.user_id, expires_at = excluded.expires_at;
  return true;
end $$;

-- فتح القفل بكلمة المرور الثانية: 5 محاولات غلط تقفل الحساب 15 دقيقة
create or replace function public.admin_unlock(pin text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare a admins%rowtype; f int;
begin
  select * into a from admins where user_id = auth.uid();
  if not found or a.pin_hash is null then raise exception 'not_allowed'; end if;
  if a.locked_until is not null and a.locked_until > now() then
    return jsonb_build_object('ok', false, 'locked_until', a.locked_until);
  end if;
  if a.pin_hash = crypt(coalesce(pin, ''), a.pin_hash) then
    update admins set fails = 0, locked_until = null where user_id = a.user_id;
    delete from admin_sessions where expires_at < now();
    insert into admin_sessions (session_id, user_id, expires_at) values (public.sid(), a.user_id, now() + interval '12 hours')
      on conflict (session_id) do update set user_id = excluded.user_id, expires_at = excluded.expires_at;
    return jsonb_build_object('ok', true);
  end if;
  f := a.fails + 1;
  if f >= 5 then
    update admins set fails = 0, locked_until = now() + interval '15 minutes' where user_id = a.user_id;
    return jsonb_build_object('ok', false, 'locked_until', now() + interval '15 minutes');
  end if;
  update admins set fails = f where user_id = a.user_id;
  return jsonb_build_object('ok', false, 'left', 5 - f);
end $$;

create or replace function public.admin_lock() returns void
language sql security definer set search_path = public as $$
  delete from admin_sessions where session_id = public.sid() and user_id = auth.uid()
$$;

-- ============ حسابات العملاء ============
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, email, name, discord)
  values (new.id, new.email, left(coalesce(new.raw_user_meta_data ->> 'name', ''), 60), left(coalesce(new.raw_user_meta_data ->> 'discord', ''), 60))
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
insert into public.profiles (id, email) select id, email from auth.users on conflict (id) do nothing;

-- ============ الطلبات ============
-- السعر والخصم يُحسبان هنا في الخادم من جدول المنتجات، مو من المتصفح
create or replace function public.check_coupon(p_code text) returns int
language sql stable security definer set search_path = public as $$
  select pct from coupons where active and upper(code) = upper(trim(coalesce(p_code, '')))
$$;

create or replace function public.place_order(p_items jsonb, p_coupon text default null) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare uid uuid := auth.uid(); v_items jsonb; v_sub numeric; v_pct int; o orders%rowtype; pr profiles%rowtype;
begin
  if uid is null then raise exception 'login_required'; end if;
  if coalesce((select data ->> 'maint' from settings where id = 1), '0') = '1' then raise exception 'maintenance'; end if;
  if (select count(*) from orders where user_id = uid and created_at > now() - interval '1 hour') >= 5 then raise exception 'too_many_orders'; end if;
  if jsonb_typeof(p_items) is distinct from 'array' then raise exception 'empty_cart'; end if;
  select jsonb_agg(jsonb_build_object('id', p.id, 'n', p.name, 'p', p.price, 'q', 1) order by p.sort), sum(p.price)
    into v_items, v_sub
    from products p where p.active and p.id in (select distinct jsonb_array_elements_text(p_items));
  if v_items is null then raise exception 'empty_cart'; end if;
  v_pct := public.check_coupon(p_coupon);
  select * into pr from profiles where id = uid;
  insert into orders (ref, user_id, cu, cfx, items, subtotal, total, coupon, pct, pay, status)
  values ('ROX-' || upper(substr(encode(gen_random_bytes(4), 'hex'), 1, 6)), uid, coalesce(nullif(pr.name, ''), pr.email, ''), coalesce(pr.cfx, ''),
          v_items, v_sub, round(v_sub * (1 - coalesce(v_pct, 0) / 100.0), 2), case when v_pct is null then null else upper(trim(p_coupon)) end, v_pct, 'bank', 'pending')
  returning * into o;
  return to_jsonb(o);
end $$;

-- العميل يربط إيصاله بطلبه هو فقط، والملف لازم يكون داخل مجلده
create or replace function public.attach_receipt(p_order bigint, p_path text, p_hash text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or p_path is null or p_path not like auth.uid()::text || '/%' then raise exception 'not_allowed'; end if;
  update orders set receipt_path = p_path, receipt_hash = left(p_hash, 64), status = 'review', chk = null
    where id = p_order and user_id = auth.uid() and status in ('pending', 'review');
  if not found then raise exception 'order_not_found'; end if;
  return true;
end $$;

-- ============ صلاحيات الصفوف (RLS) ============
alter table public.profiles enable row level security;
alter table public.admins enable row level security;
alter table public.admin_sessions enable row level security;
alter table public.products enable row level security;
alter table public.settings enable row level security;
alter table public.coupons enable row level security;
alter table public.orders enable row level security;
alter table public.activity_log enable row level security;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select using (id = auth.uid() or public.is_admin());
drop policy if exists profiles_edit on public.profiles;
create policy profiles_edit on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from anon, authenticated;
grant update (name, discord, cfx) on public.profiles to authenticated;

-- جدولا الأدمن وجلساته: ما لهم أي سياسة، فما يوصلهم أحد إلا عبر الدوال فوق

drop policy if exists products_read on public.products;
create policy products_read on public.products for select using (active or public.is_admin());
drop policy if exists products_admin on public.products;
create policy products_admin on public.products for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists settings_read on public.settings;
create policy settings_read on public.settings for select using (true);
drop policy if exists settings_admin on public.settings;
create policy settings_admin on public.settings for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists coupons_admin on public.coupons;
create policy coupons_admin on public.coupons for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists orders_read on public.orders;
create policy orders_read on public.orders for select using (user_id = auth.uid() or public.is_admin());
drop policy if exists orders_admin on public.orders;
create policy orders_admin on public.orders for all using (public.is_admin()) with check (public.is_admin());

drop policy if exists log_admin on public.activity_log;
create policy log_admin on public.activity_log for all using (public.is_admin()) with check (public.is_admin());

-- ============ البيانات الافتراضية ============
insert into public.settings (id, data) values (1, jsonb_build_object(
  'currency', '$', 'discord', '', 'checkout', '', 'liveServer', '', 'bundleEnds', '2026-12-31T23:59:59+03:00',
  'maint', 0, 'mmsg', '', 'mdate', '', 'design', 'rox', 'announce', '', 'sarRate', 3.75,
  'bank', jsonb_build_object('bankName', '', 'holder', 'عبدالله فهد الشمري', 'iban', 'SA7680000469608016053450', 'account', '469000010006086053450')
)) on conflict (id) do nothing;
-- لو اسم المستفيد فاضي في إعدادات محفوظة من قبل، نعبّيه
update public.settings set data = jsonb_set(data, '{bank,holder}', to_jsonb('عبدالله فهد الشمري'::text))
  where id = 1 and coalesce(data -> 'bank' ->> 'holder', '') = '';

insert into public.products (id, cat, art, name, descr, price, old_price, fw, h, tag, is_new, sort) values
  ('pd', 'mlo', 'ROX PD', 'مركز الشرطة — ROX PD', 'مركز كامل: استقبال، زنازين، غرفة تحقيق، مخزن سلاح وكراج.', 59.99, null, '["MLO","YMAP"]', 215, 'الأكثر مبيعًا', false, 1),
  ('med', 'mlo', 'MEDICAL', 'مستشفى Central Medical', 'طوارئ، غرف عمليات، صيدلية ومهبط طيران على السطح.', 39.99, null, '["MLO","YMAP"]', 200, null, false, 2),
  ('tuner', 'mlo', 'TUNER', 'ورشة Tuner Garage', 'ورشة تعديل برافعات، غرفة صبغ، ومعرض للسيارات.', 34.99, null, '["MLO"]', 232, 'جديد', true, 3),
  ('hud', 'script', 'HUD', 'ROX HUD', 'واجهة لاعب نظيفة: صحة، درع، جوع، عدّاد سرعة وخريطة.', 24.99, null, '["ESX","QB","QBOX"]', 4, null, false, 4),
  ('inv', 'script', 'INVENTORY', 'ROX Inventory', 'حقيبة بالسحب والإفلات، أوزان، متاجر، وصناديق سيارات.', 44.99, 59.99, '["ESX","QB","QBOX"]', 18, null, false, 5),
  ('garage', 'script', 'GARAGE', 'ROX Garage', 'كراجات عامة وخاصة، حجز، ومفاتيح مشتركة بين اللاعبين.', 29.99, null, '["ESX","QB","QBOX"]', 350, null, false, 6),
  ('bank', 'script', 'BANKING', 'ROX Banking', 'حسابات شخصية ومشتركة، فواتير، وسجل عمليات كامل.', 27.99, null, '["ESX","QB"]', 28, null, false, 7),
  ('multichar', 'script', 'MULTICHAR', 'ROX Multichar', 'اختيار شخصيات سينمائي مع نقاط سباون وخانات قابلة للفتح.', 21.99, null, '["QB","QBOX"]', 338, 'جديد', true, 8),
  ('dispatch', 'script', 'DISPATCH', 'ROX Dispatch', 'بلاغات للشرطة والإسعاف مع أكواد وتتبّع على الخريطة.', 34.99, null, '["ESX","QB","QBOX"]', 10, null, false, 9),
  ('patrol', 'car', 'PATROL', 'باقة سيارات الدوريات', '8 سيارات شرطة بإضاءات ELS وهاندلنق مضبوط.', 34.99, null, '["ADDON","ELS"]', 38, null, false, 10),
  ('drift', 'car', 'DRIFT', 'ROX Drift Pack', '6 سيارات دريفت بأصوات محركات وتعديلات كاملة.', 26.99, 33.99, '["ADDON"]', 50, null, false, 11),
  ('eup', 'eup', 'EUP', 'باقة ملابس Police + EMS', 'زي رسمي كامل للشرطة والإسعاف، رجالي ونسائي.', 19.99, null, '["EUP"]', 160, null, false, 12),
  ('bundle-starter', 'bundle', 'STARTER', 'باقة تشغيل ROX', 'سكربتات + مابات + سيارات في باقة وحدة متوافقة.', 149.99, 239.99, '["ESX","QB","QBOX"]', 4, 'وفّر 37%', false, 13)
on conflict (id) do nothing;

-- ============ الأدمن ============
-- أقدم حساب في المشروع يصير أدمن (لو ما فيه أدمن من قبل). أنشئ حسابك أول واحد.
insert into public.admins (user_id)
select id from auth.users where not exists (select 1 from public.admins) order by created_at limit 1
on conflict (user_id) do nothing;

--#storage
-- ============ تخزين الإيصالات (خاص، صور فقط، 5 ميجا) ============
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipts', 'receipts', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists receipts_upload on storage.objects;
create policy receipts_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists receipts_read on storage.objects;
create policy receipts_read on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
--#end

select 'تم الإعداد. الأدمن: ' || coalesce((select string_agg(u.email, ', ') from public.admins a join auth.users u on u.id = a.user_id), 'ما فيه حساب بعد — أنشئ حسابك ثم شغّل الملف مرة ثانية') as result;
