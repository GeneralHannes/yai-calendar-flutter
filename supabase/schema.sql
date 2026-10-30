-- Yai Calendar shared calendar. Run once in Supabase: SQL Editor -> New query.
-- Access model: everyone who knows the same calendar code shares one calendar.
-- The app sends the code in the `x-calendar-code` header; row level security
-- only lets a request see and change rows whose calendar_code matches it.

create table if not exists public.events (
  calendar_code text not null check (char_length(calendar_code) >= 8),
  id            text not null,
  title         text not null default '',
  description   text,
  location      text,
  start_at      timestamptz not null,
  end_at        timestamptz not null,
  all_day       boolean not null default false,
  updated_at    timestamptz not null default now(),
  deleted       boolean not null default false,
  seq           bigint not null default 0,
  primary key (calendar_code, id)
);

create index if not exists events_code_seq on public.events (calendar_code, seq);

-- Every insert/update gets the next sequence number: the sync cursor.
create sequence if not exists public.events_seq;

create or replace function public.events_touch() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.seq := nextval('public.events_seq');
  return new;
end $$;

drop trigger if exists events_touch on public.events;
create trigger events_touch before insert or update on public.events
  for each row execute function public.events_touch();

create or replace function public.request_code() returns text
language sql stable as $$
  select nullif(current_setting('request.headers', true)::json ->> 'x-calendar-code', '')
$$;

alter table public.events enable row level security;

drop policy if exists "calendar code" on public.events;
create policy "calendar code" on public.events
  for all to anon
  using (calendar_code = public.request_code())
  with check (calendar_code = public.request_code());

grant select, insert, update on public.events to anon;
