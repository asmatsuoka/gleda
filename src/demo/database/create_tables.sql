create table if not exists orders(
  id uuid primary key default gen_random_uuid(),
  payload jsonb not null,
  created_at timestamp not null default now()
);