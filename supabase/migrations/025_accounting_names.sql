-- ============================================================
-- ELVARIS ERP
-- Migration 025
-- Accounting Names
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from pg_type
        where typname = 'accounting_name_type'
          and typnamespace = 'public'::regnamespace
    ) then

        create type public.accounting_name_type as enum (
            'customer',
            'vendor',
            'employee',
            'other'
        );

    end if;

end
$$;


create table if not exists public.accounting_names (

    id uuid primary key
        default gen_random_uuid(),

    company_id uuid not null
        references public.companies(id)
        on delete restrict,

    name_code varchar(50) not null,

    name_type public.accounting_name_type not null,

    display_name varchar(200) not null,

    legal_name varchar(200),

    phone varchar(80),

    email varchar(255),

    address_line_1 text,

    address_line_2 text,

    city text,

    state text,

    postal_code text,

    country_id uuid,

    tax_registration_number varchar(100),

    notes text,

    is_active boolean not null
        default true,

    created_at timestamptz not null
        default now(),

    created_by uuid,

    updated_at timestamptz not null
        default now(),

    updated_by uuid

);


create unique index if not exists
ux_accounting_names_company_code
on public.accounting_names (
    company_id,
    name_code
);


create index if not exists
idx_accounting_names_company_type
on public.accounting_names (
    company_id,
    name_type
);


create index if not exists
idx_accounting_names_company_active
on public.accounting_names (
    company_id,
    is_active
);


create index if not exists
idx_accounting_names_display_name
on public.accounting_names (
    company_id,
    lower(display_name)
);


create index if not exists
idx_accounting_names_legal_name
on public.accounting_names (
    company_id,
    lower(legal_name)
);


alter table public.accounting_names
drop constraint if exists
    accounting_names_display_name_not_blank;


alter table public.accounting_names
add constraint
    accounting_names_display_name_not_blank
check (
    length(trim(display_name)) > 0
);


alter table public.accounting_names
drop constraint if exists
    accounting_names_code_not_blank;


alter table public.accounting_names
add constraint
    accounting_names_code_not_blank
check (
    length(trim(name_code)) > 0
);


-- ============================================================
-- Add generalized Name reference to journal lines
-- ============================================================

alter table public.journal_entry_lines
add column if not exists
    name_id uuid
    references public.accounting_names(id)
    on delete restrict;


create index if not exists
idx_journal_lines_name
on public.journal_entry_lines (
    name_id
);


-- ============================================================
-- Validate Name belongs to the same company as the journal
-- ============================================================

create or replace function public.validate_journal_line_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_entry_company_id uuid;
    v_name_company_id uuid;

begin

    if new.name_id is null then
        return new;
    end if;


    select company_id
    into v_entry_company_id
    from public.journal_entries
    where id = new.journal_entry_id;


    if v_entry_company_id is null then

        raise exception
            'Journal entry does not exist.';

    end if;


    select company_id
    into v_name_company_id
    from public.accounting_names
    where id = new.name_id;


    if v_name_company_id is null then

        raise exception
            'Accounting Name does not exist.';

    end if;


    if v_entry_company_id <> v_name_company_id then

        raise exception
            'Accounting Name and journal entry belong to different companies.';

    end if;


    return new;

end;
$function$;


drop trigger if exists
trg_validate_journal_line_name
on public.journal_entry_lines;


create trigger
trg_validate_journal_line_name
before insert or update
on public.journal_entry_lines
for each row
execute function public.validate_journal_line_name();


-- ============================================================
-- Determine whether the selected account requires a Name
-- ============================================================

create or replace function public.journal_account_name_required(
    p_account_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_required boolean;

begin

    select
        coa.name_requirement =
            'required'::public.account_name_requirement
    into v_required
    from public.chart_of_accounts coa
    where coa.id = p_account_id;


    if v_required is null then

        raise exception
            'Account does not exist.';

    end if;


    return v_required;

end;
$function$;


-- ============================================================
-- Validate Name requirement at posting time
-- ============================================================

create or replace function public.validate_journal_entry_names(
    p_journal_entry_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_line record;

begin

    for v_line in
        select
            jel.line_number,
            jel.account_id,
            jel.name_id,
            coa.account_code,
            coa.account_name,
            coa.name_requirement
        from public.journal_entry_lines jel
        join public.chart_of_accounts coa
            on coa.id = jel.account_id
        where jel.journal_entry_id = p_journal_entry_id
    loop

        if v_line.name_requirement =
           'required'::public.account_name_requirement
        then

            if v_line.name_id is null then

                raise exception
                    'Journal line % requires a Name because account "%" requires a Name.',
                    v_line.line_number,
                    v_line.account_code;

            end if;

        end if;


        if v_line.name_id is not null then

            if not exists (
                select 1
                from public.accounting_names an
                where an.id = v_line.name_id
                  and an.company_id = (
                      select company_id
                      from public.journal_entries
                      where id = p_journal_entry_id
                  )
                  and an.is_active = true
            ) then

                raise exception
                    'Journal line % references an invalid or inactive Accounting Name.',
                    v_line.line_number;

            end if;

        end if;

    end loop;


    return true;

end;
$function$;


-- ============================================================
-- Update posting engine to validate Names
-- ============================================================

create or replace function public.post_journal_entry(
    p_journal_entry_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_entry public.journal_entries%rowtype;
    v_total_debit numeric(20,6);
    v_total_credit numeric(20,6);
    v_posted_status public.journal_entry_status;

begin

    select *
    into v_entry
    from public.journal_entries
    where id = p_journal_entry_id
    for update;


    if not found then

        raise exception
            'Journal entry does not exist.';

    end if;


    if v_entry.status <> 'draft'::public.journal_entry_status then

        raise exception
            'Only draft journal entries can be posted. Current status: %.',
            v_entry.status;

    end if;


    perform public.validate_journal_entry_header(
        p_journal_entry_id
    );


    perform public.validate_journal_period(
        p_journal_entry_id
    );


    perform public.validate_journal_entry_lines(
        p_journal_entry_id
    );


    perform public.validate_journal_entry_names(
        p_journal_entry_id
    );


    select
        coalesce(sum(debit), 0),
        coalesce(sum(credit), 0)
    into
        v_total_debit,
        v_total_credit
    from public.journal_entry_lines
    where journal_entry_id = p_journal_entry_id;


    if v_total_debit = 0 then

        raise exception
            'Journal entry total cannot be zero.';

    end if;


    if abs(v_total_debit - v_total_credit) > 0.000001 then

        raise exception
            'Journal entry is not balanced. Debits: %, Credits: %, Difference: %.',
            v_total_debit,
            v_total_credit,
            v_total_debit - v_total_credit;

    end if;


    update public.journal_entries
    set
        status = 'posted'::public.journal_entry_status,
        posted_at = now(),
        posted_by = coalesce(
            auth.uid(),
            posted_by
        ),
        updated_at = now(),
        updated_by = coalesce(
            auth.uid(),
            updated_by
        )
    where id = p_journal_entry_id
      and status = 'draft'::public.journal_entry_status
    returning status
    into v_posted_status;


    if v_posted_status is null then

        raise exception
            'Journal entry could not be posted because its status changed.';

    end if;


    return p_journal_entry_id;

end;
$function$;


-- ============================================================
-- Accounting Name code generator
-- ============================================================

create or replace function public.next_accounting_name_code(
    p_company_id uuid,
    p_name_type public.accounting_name_type
)
returns varchar(50)
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_prefix varchar(10);
    v_max integer;
begin

    v_prefix :=
        case p_name_type
            when 'customer' then 'CUS-'
            when 'vendor' then 'VEN-'
            when 'employee' then 'EMP-'
            else 'OTH-'
        end;


    select coalesce(
        max(
            nullif(
                regexp_replace(
                    name_code,
                    '[^0-9]',
                    '',
                    'g'
                ),
                ''
            )::integer
        ),
        0
    )
    into v_max
    from public.accounting_names
    where company_id = p_company_id
      and name_type = p_name_type;


    return
        v_prefix
        || lpad(
            (v_max + 1)::text,
            6,
            '0'
        );

end;
$function$;


-- ============================================================
-- Create Accounting Name
-- ============================================================

create or replace function public.create_accounting_name(
    p_company_id uuid,
    p_name_type public.accounting_name_type,
    p_display_name varchar(200),
    p_name_code varchar(50) default null,
    p_legal_name varchar(200) default null,
    p_phone varchar(80) default null,
    p_email varchar(255) default null,
    p_address_line_1 text default null,
    p_address_line_2 text default null,
    p_city text default null,
    p_state text default null,
    p_postal_code text default null,
    p_country_id uuid default null,
    p_tax_registration_number varchar(100) default null,
    p_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_id uuid;
    v_code varchar(50);

begin

    if not exists (
        select 1
        from public.companies c
        where c.id = p_company_id
          and c.is_active = true
    ) then

        raise exception
            'Active company does not exist.';

    end if;


    if nullif(trim(p_display_name), '') is null then

        raise exception
            'Display name is required.';

    end if;


    if p_name_code is null then

        v_code :=
            public.next_accounting_name_code(
                p_company_id,
                p_name_type
            );

    else

        v_code := trim(p_name_code);

    end if;


    if exists (
        select 1
        from public.accounting_names
        where company_id = p_company_id
          and name_code = v_code
    ) then

        raise exception
            'Accounting Name code "%" already exists.',
            v_code;

    end if;


    insert into public.accounting_names (
        company_id,
        name_code,
        name_type,
        display_name,
        legal_name,
        phone,
        email,
        address_line_1,
        address_line_2,
        city,
        state,
        postal_code,
        country_id,
        tax_registration_number,
        notes,
        is_active,
        created_at,
        created_by,
        updated_at,
        updated_by
    )
    values (
        p_company_id,
        v_code,
        p_name_type,
        trim(p_display_name),
        p_legal_name,
        p_phone,
        p_email,
        p_address_line_1,
        p_address_line_2,
        p_city,
        p_state,
        p_postal_code,
        p_country_id,
        p_tax_registration_number,
        p_notes,
        true,
        now(),
        auth.uid(),
        now(),
        auth.uid()
    )
    returning id
    into v_id;


    return v_id;

end;
$function$;


-- ============================================================
-- Partial Search
-- ============================================================

create or replace function public.search_accounting_names(
    p_company_id uuid,
    p_search text default null,
    p_name_type public.accounting_name_type default null,
    p_limit integer default 50
)
returns table (
    id uuid,
    name_code varchar(50),
    name_type public.accounting_name_type,
    display_name varchar(200),
    legal_name varchar(200),
    phone varchar(80),
    email varchar(255)
)
language sql
security definer
stable
set search_path = public
as $function$

    select
        an.id,
        an.name_code,
        an.name_type,
        an.display_name,
        an.legal_name,
        an.phone,
        an.email

    from public.accounting_names an

    where an.company_id = p_company_id

      and an.is_active = true

      and (
          p_name_type is null
          or an.name_type = p_name_type
      )

      and (
          nullif(trim(p_search), '') is null

          or an.name_code ilike
                '%' || trim(p_search) || '%'

          or an.display_name ilike
                '%' || trim(p_search) || '%'

          or coalesce(
                an.legal_name,
                ''
             ) ilike
                '%' || trim(p_search) || '%'

          or coalesce(
                an.phone,
                ''
             ) ilike
                '%' || trim(p_search) || '%'

          or coalesce(
                an.email,
                ''
             ) ilike
                '%' || trim(p_search) || '%'
      )

    order by
        an.display_name

    limit greatest(
        least(
            coalesce(p_limit, 50),
            200
        ),
        1
    );

$function$;


-- ============================================================
-- Comments
-- ============================================================

comment on table public.accounting_names
is
    'Common accounting identity layer for Customers, Vendors, Employees and Other accounting names.';


comment on column public.journal_entry_lines.name_id
is
    'Optional or required accounting Name determined by the selected account behavior.';


comment on function public.validate_journal_entry_names(
    uuid
)
is
    'Validates required and optional accounting Names on journal lines before posting.';


comment on function public.search_accounting_names(
    uuid,
    text,
    public.accounting_name_type,
    integer
)
is
    'Performs partial search across accounting Name code, display name, legal name, phone and email.';


-- ============================================================
-- Validation
-- ============================================================

do $$
begin

    if not exists (
        select 1
        from information_schema.tables
        where table_schema = 'public'
          and table_name = 'accounting_names'
    ) then

        raise exception
            'accounting_names table was not created.';

    end if;


    if not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'journal_entry_lines'
          and column_name = 'name_id'
    ) then

        raise exception
            'journal_entry_lines.name_id was not created.';

    end if;


    if not exists (
        select 1
        from public.chart_of_accounts
        where system_account_code = 'accounts_receivable'
          and name_requirement =
              'required'::public.account_name_requirement
    ) then

        raise exception
            'Accounts Receivable Name requirement is not configured.';

    end if;


    if not exists (
        select 1
        from public.chart_of_accounts
        where system_account_code = 'accounts_payable'
          and name_requirement =
              'required'::public.account_name_requirement
    ) then

        raise exception
            'Accounts Payable Name requirement is not configured.';

    end if;

end
$$;


-- ============================================================
-- END MIGRATION 025
-- ============================================================