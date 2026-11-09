-- Group 9 - HR Onboarding & Compliance Automation
-- Supabase setup script (policies, start-date rule)

--creating the public.employees table (values will be unique)
INSERT INTO public.employees (id_no, first_name, last_name, email_address, department, progress, start_date, envelope_id) 
VALUES ('0101010000001', 'Sipho', 'Khumalo', 'sipho.khumalo@example.com', 'Sales', 'Confirmed', '2026-11-13', '6e006dd2-4ea7-8834-8169-dec36bee3d89'), 
('0145238412057', 'Thabo', 'Mokoena', 'thabomokoena12@example.com', 'Sales', 'Not Started', null, null), 
('0202020000002', 'Nomsa', 'Dube', 'nomsa.dube@example.com', 'Finance', 'Completed', '2026-10-19', null), 
('0303030000003', 'Johan', 'Botha', 'johan.botha@example.com', 'IT', 'Signed', '2026-11-16', null), 
('0345712369541', 'Aisha', 'Naidoo', 'aisha.naidoo@example.com', 'Finance', 'Not Started', null, null), 
('0423651477102', 'Learto', 'Dlamini', 'lerato.dlamini@example.com', 'Human Resources', 'Not Started', null, null), 
('0634586535906', 'Amu', 'Mabs', 'amukelani.mabunda16@gmail.com', 'IT', 'Not Started', '2026-11-09', '821f479c-31f3-8084-80aa-c5cf7fbfb35f'), 
('9757975789764', 'Chid', 'Chuk', 'dampest-dozen.4e@icloud.com', 'IT', 'Not Started', null, '');
-- row level security

alter table public.employees enable row level security;

-- Reading: the chatbot looks employees up by ID, and the dashboard lists them.
drop policy if exists "allow read employees" on public.employees;
create policy "allow read employees"
on public.employees
for select
using (true);

-- Updating: the chatbot saves edited details and changes Progress,
-- the dashboard confirms contracts and edits profiles,
-- and Zapier sets Progress to Signed.
drop policy if exists "allow update employees" on public.employees;
create policy "allow update employees"
on public.employees
for update
using (true)
with check (true);

-- Adding: the dashboard's "Add employee" form.
drop policy if exists "allow insert employees" on public.employees;
create policy "allow insert employees"
on public.employees
for insert
with check (true);



-- start date calculation
-- When an employee's Progress changes to Confirmed, start_date is set to
-- 5 business days later (Saturdays and Sundays are skipped; public
-- holidays are not).

--Counts forward a number of business days
create or replace function public.add_business_days(start_day date, days int)
returns date
language plpgsql
immutable
as $$
declare
  d date := start_day;
  added int := 0;
begin
  while added < days loop
    d := d + 1;
    if extract(isodow from d) < 6 then   -- 1 = Monday ... 5 = Friday
      added := added + 1;
    end if;
  end loop;
  return d;
end;
$$;

--Sets start_date when Progress becomes Confirmed
create or replace function public.set_start_date_on_confirm()
returns trigger
language plpgsql
as $$
begin
  if lower(trim(NEW.progress)) = 'confirmed'
     and lower(trim(coalesce(OLD.progress, ''))) is distinct from 'confirmed' then
    NEW.start_date := public.add_business_days(
      (now() at time zone 'Africa/Johannesburg')::date, 5
    );
  end if;
  return NEW;
end;
$$;

--Attach the rule to the employees table
drop trigger if exists trg_set_start_date on public.employees;

create trigger trg_set_start_date
before update of progress on public.employees
for each row
execute function public.set_start_date_on_confirm();

--create dashboard.users table
create table if not exists dashboard_users (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  display_name text not null,
  salt text not null,
  pw_hash text not null,
  created_at timestamptz default now()
);
alter table dashboard_users enable row level security;

--setting up policies 
create policy "anon read users" on dashboard_users  --- allows users of the hronboard dashboard to create accounts
  for select to anon using (true);

create policy "anon insert users" on dashboard_users 
  for insert to anon with check (true);

create policy "anon insert employees" on employees --dashboard (allows hr to insert employees)
  for insert to anon with check (true);

  create policy "anon update employees" on employees -- allows hr to update employee info in dashboard
  for update to anon using (true) with check (true);

--end