create table if not exists public.medical_records (
  id          uuid primary key default gen_random_uuid(),
  patient_uid text not null,
  doctor_uid  text,
  doctor_name text,
  diagnosis   text not null check (length(diagnosis) between 1 and 500),
  notes       text check (notes is null or length(notes) <= 10000),
  record_date date not null default current_date,
  status      text not null default 'final'
              check (status in ('draft', 'final', 'amended')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists medical_records_patient_idx
  on public.medical_records (patient_uid, record_date desc);

create table if not exists public.appointments (
  id          text primary key,
  patient_uid text not null,
  doctor_id   text not null,
  doctor_name text,
  starts_at   timestamptz not null,
  status      text not null default 'confirmed',
  synced_at   timestamptz not null default now()
);

create index if not exists appointments_patient_idx
  on public.appointments (patient_uid);
create index if not exists appointments_doctor_idx
  on public.appointments (doctor_id, patient_uid);

create table if not exists public.access_log (
  id          bigint generated always as identity primary key,
  actor_uid   text not null,
  actor_role  text,
  action      text not null,
  patient_uid text,
  at          timestamptz not null default now()
);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists medical_records_touch on public.medical_records;
create trigger medical_records_touch
  before update on public.medical_records
  for each row execute function public.touch_updated_at();

alter table public.medical_records enable row level security;
alter table public.appointments enable row level security;
alter table public.access_log enable row level security;

revoke all on public.medical_records, public.appointments, public.access_log
  from anon, authenticated;
revoke all on function public.touch_updated_at()
  from anon, authenticated, public;

grant all privileges on table public.medical_records, public.appointments,
  public.access_log to service_role;
grant usage, select on sequence public.access_log_id_seq to service_role;
grant execute on function public.touch_updated_at() to service_role;
