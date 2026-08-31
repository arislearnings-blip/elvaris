-- ============================================================
-- ELVARIS ERP
-- Migration 015
-- Chart of Accounts Structural Refinement
-- ============================================================

do $$
begin
    if not exists (
        select 1
        from pg_type
        where typname = 'account_role'
          and typnamespace = 'public'::regnamespace
    ) then
        create type public.account_role as enum (
            'header',
            'posting',
            'control'
        );
    end if;
end
$$;


do $$
begin
    if not exists (
        select 1
        from pg_type
        where typname = 'account_node_type'
          and typnamespace = 'public'::regnamespace
    ) then
        create type public.account_node_type as enum (
            'report_group',
            'account'
        );
    end if;
end
$$;


alter table public.chart_of_accounts
add column if not exists display_order integer not null default 0;


alter table public.chart_of_accounts
add column if not exists account_depth smallint not null default 0;


alter table public.chart_of_accounts
add column if not exists account_path text;


alter table public.chart_of_accounts
add column if not exists account_role public.account_role;


alter table public.chart_of_accounts
add column if not exists node_type public.account_node_type;


alter table public.chart_of_accounts
add column if not exists is_system_account boolean not null default false;


alter table public.chart_of_accounts
add column if not exists is_locked boolean not null default false;


update public.chart_of_accounts
set account_role =
    case
        when is_control_account then 'control'::public.account_role
        when is_header then 'header'::public.account_role
        else 'posting'::public.account_role
    end
where account_role is null;


update public.chart_of_accounts
set node_type =
    case
        when is_header then 'report_group'::public.account_node_type
        else 'account'::public.account_node_type
    end
where node_type is null;


update public.chart_of_accounts
set account_depth = 0
where parent_account_id is null;


update public.chart_of_accounts
set account_path = account_code
where parent_account_id is null
  and account_path is null;


alter table public.chart_of_accounts
drop constraint if exists chart_of_accounts_display_order_check;


alter table public.chart_of_accounts
add constraint chart_of_accounts_display_order_check
check (display_order >= 0);


alter table public.chart_of_accounts
drop constraint if exists chart_of_accounts_account_depth_check;


alter table public.chart_of_accounts
add constraint chart_of_accounts_account_depth_check
check (
    account_depth >= 0
    and account_depth <= 50
);


alter table public.chart_of_accounts
drop constraint if exists chart_of_accounts_code_not_blank;


alter table public.chart_of_accounts
add constraint chart_of_accounts_code_not_blank
check (length(trim(account_code)) > 0);


alter table public.chart_of_accounts
drop constraint if exists chart_of_accounts_name_not_blank;


alter table public.chart_of_accounts
add constraint chart_of_accounts_name_not_blank
check (length(trim(account_name)) > 0);


alter table public.chart_of_accounts
drop constraint if exists chart_of_accounts_role_consistency_check;


alter table public.chart_of_accounts
add constraint chart_of_accounts_role_consistency_check
check (
    (
        account_role = 'header'
        and is_header = true
        and is_posting = false
        and is_control_account = false
        and allow_manual_posting = false
    )
    or
    (
        account_role = 'posting'
        and is_header = false
        and is_posting = true
        and is_control_account = false
    )
    or
    (
        account_role = 'control'
        and is_header = false
        and is_posting = true
        and is_control_account = true
    )
);


alter table public.chart_of_accounts
drop constraint if exists chart_of_accounts_node_type_check;


alter table public.chart_of_accounts
add constraint chart_of_accounts_node_type_check
check (
    (
        node_type = 'report_group'
        and account_role = 'header'
    )
    or
    node_type = 'account'
);


alter table public.chart_of_accounts
drop constraint if exists chart_of_accounts_system_lock_check;


alter table public.chart_of_accounts
add constraint chart_of_accounts_system_lock_check
check (
    is_system_account = false
    or is_locked = true
);


create index if not exists idx_coa_company_parent
on public.chart_of_accounts (
    company_id,
    parent_account_id
);


create index if not exists idx_coa_company_order
on public.chart_of_accounts (
    company_id,
    display_order
);


create index if not exists idx_coa_company_path
on public.chart_of_accounts (
    company_id,
    account_path
);


create index if not exists idx_coa_company_role
on public.chart_of_accounts (
    company_id,
    account_role
);


create index if not exists idx_coa_company_system
on public.chart_of_accounts (
    company_id,
    is_system_account
);


comment on column public.chart_of_accounts.account_role
is 'Header, posting, or control account.';


comment on column public.chart_of_accounts.node_type
is 'Report-group node or actual ledger account.';


comment on column public.chart_of_accounts.display_order
is 'Ordering of accounts within the Chart of Accounts hierarchy.';


comment on column public.chart_of_accounts.account_depth
is 'Hierarchy depth. Zero is the top level.';


comment on column public.chart_of_accounts.account_path
is 'Hierarchical account-code path.';


comment on column public.chart_of_accounts.is_system_account
is 'Indicates an account required by Elvaris system accounting processes.';


comment on column public.chart_of_accounts.is_locked
is 'Prevents destructive changes to protected system accounts.';


do $$
begin
    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'chart_of_accounts'
          and column_name = 'display_order'
    ) then
        raise exception 'display_order was not created.';
    end if;

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'chart_of_accounts'
          and column_name = 'account_depth'
    ) then
        raise exception 'account_depth was not created.';
    end if;

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'chart_of_accounts'
          and column_name = 'account_path'
    ) then
        raise exception 'account_path was not created.';
    end if;

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'chart_of_accounts'
          and column_name = 'account_role'
    ) then
        raise exception 'account_role was not created.';
    end if;

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'chart_of_accounts'
          and column_name = 'node_type'
    ) then
        raise exception 'node_type was not created.';
    end if;

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'chart_of_accounts'
          and column_name = 'is_system_account'
    ) then
        raise exception 'is_system_account was not created.';
    end if;

    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'chart_of_accounts'
          and column_name = 'is_locked'
    ) then
        raise exception 'is_locked was not created.';
    end if;
end
$$;