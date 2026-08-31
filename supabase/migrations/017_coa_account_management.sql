-- ============================================================
-- ELVARIS ERP
-- Migration 017
-- Chart of Accounts Account Management
-- ============================================================
--
-- Provides controlled database operations for:
--
--   - Create account
--   - Create subaccount
--   - Edit account
--   - Activate / deactivate account
--   - Move account
--   - Generate next account code
--   - Prevent posting to headers
--   - Protect system accounts
--   - Prevent invalid hierarchy
--
-- No ledger tables are referenced here because the accounting
-- transaction engine has not yet been finalized.
--
-- All functions are SECURITY DEFINER and validate the company
-- and account hierarchy explicitly.
-- ============================================================


-- ============================================================
-- 1. NEXT ACCOUNT CODE
-- ============================================================

create or replace function public.next_coa_account_code(
    p_company_id uuid,
    p_parent_account_id uuid default null
)
returns varchar(30)
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_base_code integer;
    v_max_code integer;
    v_next_code integer;
    v_parent_code varchar(30);

begin

    -- --------------------------------------------------------
    -- Validate company
    -- --------------------------------------------------------

    if not exists (
        select 1
        from public.companies c
        where c.id = p_company_id
    ) then

        raise exception
            'Company does not exist.';

    end if;


    -- --------------------------------------------------------
    -- Root account numbering
    --
    -- 1000, 2000, 3000, ...
    -- --------------------------------------------------------

    if p_parent_account_id is null then

        select coalesce(
            max(
                nullif(
                    regexp_replace(
                        account_code,
                        '[^0-9]',
                        '',
                        'g'
                    ),
                    ''
                )::integer
            ),
            0
        )
        into v_max_code
        from public.chart_of_accounts
        where company_id = p_company_id
          and parent_account_id is null;


        if v_max_code < 1000 then
            v_next_code := 1000;
        else
            v_next_code :=
                ((v_max_code / 1000) + 1) * 1000;
        end if;


        return v_next_code::varchar(30);

    end if;


    -- --------------------------------------------------------
    -- Child account numbering
    --
    -- Determine the parent's numeric code and allocate the
    -- next available 10-based child code.
    --
    -- Example:
    --
    -- 1300
    --   1310
    --   1320
    --   1330
    --
    -- --------------------------------------------------------

    select coa.account_code
    into v_parent_code
    from public.chart_of_accounts coa
    where coa.id = p_parent_account_id
      and coa.company_id = p_company_id;


    if v_parent_code is null then

        raise exception
            'Parent account does not exist in this company.';

    end if;


    if v_parent_code !~ '^[0-9]+$' then

        raise exception
            'Automatic account numbering requires a numeric parent account code.';

    end if;


    v_base_code :=
        v_parent_code::integer;


    select coalesce(
        max(
            nullif(
                regexp_replace(
                    child.account_code,
                    '[^0-9]',
                    '',
                    'g'
                ),
                ''
            )::integer
        ),
        0
    )
    into v_max_code
    from public.chart_of_accounts child
    where child.company_id = p_company_id
      and child.parent_account_id = p_parent_account_id
      and child.account_code ~ '^[0-9]+$';


    if v_max_code <= v_base_code then

        v_next_code :=
            v_base_code + 10;

    else

        v_next_code :=
            v_max_code + 10;

    end if;


    -- --------------------------------------------------------
    -- Make sure the generated code is unused
    -- --------------------------------------------------------

    while exists (
        select 1
        from public.chart_of_accounts coa
        where coa.company_id = p_company_id
          and coa.account_code = v_next_code::varchar
    )
    loop

        v_next_code :=
            v_next_code + 10;

    end loop;


    return v_next_code::varchar(30);

end;
$function$;


-- ============================================================
-- 2. CREATE ACCOUNT
-- ============================================================

create or replace function public.create_coa_account(
    p_company_id uuid,
    p_account_name varchar(150),
    p_account_type_id uuid,
    p_parent_account_id uuid default null,
    p_description text default null,
    p_detail_type_id uuid default null,
    p_account_role public.account_role default 'posting',
    p_allow_manual_posting boolean default true,
    p_account_code varchar(30) default null,
    p_is_control_account boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_account_id uuid;
    v_code varchar(30);
    v_depth smallint;
    v_path text;
    v_parent_role public.account_role;
    v_parent_path text;
    v_category public.account_category;

begin

    -- --------------------------------------------------------
    -- Company
    -- --------------------------------------------------------

    if not exists (
        select 1
        from public.companies c
        where c.id = p_company_id
    ) then

        raise exception
            'Company does not exist.';

    end if;


    -- --------------------------------------------------------
    -- Account name
    -- --------------------------------------------------------

    if nullif(trim(p_account_name), '') is null then

        raise exception
            'Account name is required.';

    end if;


    -- --------------------------------------------------------
    -- Account type
    -- --------------------------------------------------------

    select at.account_category
    into v_category
    from public.account_types at
    where at.id = p_account_type_id
      and at.is_active = true
      and at.is_legacy = false;


    if v_category is null then

        raise exception
            'The selected account type is invalid or inactive.';

    end if;


    -- --------------------------------------------------------
    -- Detail type
    -- --------------------------------------------------------

    if p_detail_type_id is not null then

        if not exists (
            select 1
            from public.account_detail_types adt
            where adt.id = p_detail_type_id
              and adt.account_category = v_category
              and adt.is_active = true
        ) then

            raise exception
                'The selected detail type does not belong to the selected account category.';

        end if;

    end if;


    -- --------------------------------------------------------
    -- Validate role
    -- --------------------------------------------------------

    if p_account_role = 'header' then

        if p_is_control_account then

            raise exception
                'A header account cannot be a control account.';

        end if;

        if p_allow_manual_posting then

            raise exception
                'A header account cannot allow manual posting.';

        end if;

    elsif p_account_role = 'posting' then

        if p_is_control_account then

            raise exception
                'A posting account cannot be marked as a control account. Use control role.';
        end if;

    elsif p_account_role = 'control' then

        if not p_is_control_account then

            raise exception
                'A control account must have is_control_account = true.';

        end if;

    end if;


    -- --------------------------------------------------------
    -- Parent
    -- --------------------------------------------------------

    if p_parent_account_id is not null then

        select
            coa.account_role,
            coa.account_path,
            coa.account_depth
        into
            v_parent_role,
            v_parent_path,
            v_depth
        from public.chart_of_accounts coa
        where coa.id = p_parent_account_id
          and coa.company_id = p_company_id;


        if v_parent_role is null then

            raise exception
                'Parent account does not exist in this company.';

        end if;


        if v_parent_role not in (
            'header'
        ) then

            raise exception
                'Only header accounts can contain child accounts.';

        end if;


        v_depth :=
            coalesce(v_depth, 0) + 1;


    else

        v_depth := 0;

    end if;


    -- --------------------------------------------------------
    -- Account code
    -- --------------------------------------------------------

    if nullif(trim(p_account_code), '') is null then

        v_code :=
            public.next_coa_account_code(
                p_company_id,
                p_parent_account_id
            );

    else

        v_code :=
            trim(p_account_code);

    end if;


    -- --------------------------------------------------------
    -- Account code uniqueness
    -- --------------------------------------------------------

    if exists (
        select 1
        from public.chart_of_accounts coa
        where coa.company_id = p_company_id
          and coa.account_code = v_code
    ) then

        raise exception
            'Account code "%" already exists in this company.',
            v_code;

    end if;


    -- --------------------------------------------------------
    -- Account path
    -- --------------------------------------------------------

    if p_parent_account_id is null then

        v_path := v_code;

    else

        v_path :=
            v_parent_path
            || '.'
            || v_code;

    end if;


    -- --------------------------------------------------------
    -- Create
    -- --------------------------------------------------------

    insert into public.chart_of_accounts (
        company_id,
        account_type_id,
        parent_account_id,
        account_code,
        account_name,
        description,
        is_header,
        is_posting,
        is_control_account,
        system_account_code,
        allow_manual_posting,
        currency_id,
        detail_type_id,
        account_role,
        display_order,
        account_depth,
        account_path,
        is_active,
        node_type,
        is_system_account,
        is_locked,
        created_at,
        created_by,
        updated_at,
        updated_by
    )
    values (
        p_company_id,
        p_account_type_id,
        p_parent_account_id,
        v_code,
        trim(p_account_name),
        p_description,
        p_account_role = 'header',
        p_account_role <> 'header',
        p_is_control_account,
        null,
        p_allow_manual_posting,
        null,
        p_detail_type_id,
        p_account_role,
        coalesce(
            (
                select max(child.display_order) + 1
                from public.chart_of_accounts child
                where child.company_id = p_company_id
                  and child.parent_account_id is not distinct from p_parent_account_id
            ),
            1
        ),
        v_depth,
        v_path,
        true,
        case
            when p_account_role = 'header'
                then 'report_group'::public.account_node_type
            else
                'account'::public.account_node_type
        end,
        false,
        false,
        now(),
        auth.uid(),
        now(),
        auth.uid()
    )
    returning id
    into v_account_id;


    return v_account_id;

end;
$function$;


-- ============================================================
-- 3. UPDATE ACCOUNT
-- ============================================================

create or replace function public.update_coa_account(
    p_account_id uuid,
    p_account_name varchar(150),
    p_description text default null,
    p_detail_type_id uuid default null,
    p_account_code varchar(30) default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_account record;
    v_code varchar(30);
    v_category public.account_category;
    v_existing_id uuid;

begin

    select
        coa.*
    into v_account
    from public.chart_of_accounts coa
    where coa.id = p_account_id
    for update;


    if v_account.id is null then

        raise exception
            'Account does not exist.';

    end if;


    if v_account.is_system_account then

        raise exception
            'System account "%" cannot be edited through normal account maintenance.',
            v_account.account_code;

    end if;


    if nullif(trim(p_account_name), '') is null then

        raise exception
            'Account name is required.';

    end if;


    select at.account_category
    into v_category
    from public.account_types at
    where at.id = v_account.account_type_id;


    if p_detail_type_id is not null then

        if not exists (
            select 1
            from public.account_detail_types adt
            where adt.id = p_detail_type_id
              and adt.account_category = v_category
              and adt.is_active = true
        ) then

            raise exception
                'The selected detail type does not belong to the account category.';

        end if;

    end if;


    v_code :=
        coalesce(
            nullif(trim(p_account_code), ''),
            v_account.account_code
        );


    select coa.id
    into v_existing_id
    from public.chart_of_accounts coa
    where coa.company_id = v_account.company_id
      and coa.account_code = v_code
      and coa.id <> p_account_id
    limit 1;


    if v_existing_id is not null then

        raise exception
            'Account code "%" is already used by another account.',
            v_code;

    end if;


    update public.chart_of_accounts
    set
        account_code = v_code,
        account_name = trim(p_account_name),
        description = p_description,
        detail_type_id = p_detail_type_id,
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_account_id;


    return p_account_id;

end;
$function$;


-- ============================================================
-- 4. ACTIVATE / DEACTIVATE ACCOUNT
-- ============================================================

create or replace function public.set_coa_account_active(
    p_account_id uuid,
    p_is_active boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_account record;

begin

    select *
    into v_account
    from public.chart_of_accounts
    where id = p_account_id
    for update;


    if v_account.id is null then

        raise exception
            'Account does not exist.';

    end if;


    if v_account.is_system_account then

        raise exception
            'System account "%" cannot be deactivated.',
            v_account.account_code;

    end if;


    if v_account.is_header
       and p_is_active = false
       and exists (
           select 1
           from public.chart_of_accounts child
           where child.parent_account_id = p_account_id
             and child.is_active = true
       )
    then

        raise exception
            'Header account "%" cannot be deactivated while active child accounts exist.',
            v_account.account_code;

    end if;


    update public.chart_of_accounts
    set
        is_active = p_is_active,
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_account_id;


    return p_is_active;

end;
$function$;


-- ============================================================
-- 5. MOVE ACCOUNT
-- ============================================================

create or replace function public.move_coa_account(
    p_account_id uuid,
    p_new_parent_account_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare
    v_account record;
    v_parent record;
    v_depth smallint;
    v_path text;

begin

    select *
    into v_account
    from public.chart_of_accounts
    where id = p_account_id
    for update;


    if v_account.id is null then

        raise exception
            'Account does not exist.';

    end if;


    if v_account.is_system_account then

        raise exception
            'System account "%" cannot be moved.',
            v_account.account_code;

    end if;


    -- --------------------------------------------------------
    -- Root move
    -- --------------------------------------------------------

    if p_new_parent_account_id is null then

        v_depth := 0;
        v_path := v_account.account_code;


    else

        select *
        into v_parent
        from public.chart_of_accounts
        where id = p_new_parent_account_id
          and company_id = v_account.company_id;


        if v_parent.id is null then

            raise exception
                'New parent account does not exist in this company.';

        end if;


        if v_parent.account_role <> 'header' then

            raise exception
                'An account can only be placed under a header account.';

        end if;


        -- Prevent circular hierarchy.

        if exists (
            with recursive descendants as (
                select id
                from public.chart_of_accounts
                where id = p_account_id

                union all

                select child.id
                from public.chart_of_accounts child
                join descendants d
                  on child.parent_account_id = d.id
            )
            select 1
            from descendants
            where id = p_new_parent_account_id
        ) then

            raise exception
                'An account cannot be moved beneath itself or one of its descendants.';

        end if;


        v_depth :=
            v_parent.account_depth + 1;

        v_path :=
            v_parent.account_path
            || '.'
            || v_account.account_code;

    end if;


    update public.chart_of_accounts
    set
        parent_account_id = p_new_parent_account_id,
        account_depth = v_depth,
        account_path = v_path,
        updated_at = now(),
        updated_by = auth.uid()
    where id = p_account_id;


    return p_account_id;

end;
$function$;


-- ============================================================
-- 6. VALIDATE ACCOUNT MAY RECEIVE POSTING
-- ============================================================

create or replace function public.coa_account_can_post(
    p_account_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_account record;

begin

    select
        is_active,
        is_header,
        is_posting,
        allow_manual_posting
    into v_account
    from public.chart_of_accounts
    where id = p_account_id;


    if v_account.is_active is null then

        raise exception
            'Account does not exist.';

    end if;


    return
        v_account.is_active
        and v_account.is_header = false
        and v_account.is_posting = true
        and v_account.allow_manual_posting = true;

end;
$function$;


-- ============================================================
-- 7. PROTECT SYSTEM ACCOUNTS FROM NORMAL DELETE
-- ============================================================

create or replace function public.prevent_system_coa_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $function$

begin

    if old.is_system_account = true then

        raise exception
            'System account "%" cannot be deleted.',
            old.account_code;

    end if;


    return old;

end;
$function$;


drop trigger if exists
    trg_prevent_system_coa_delete
on public.chart_of_accounts;


create trigger
    trg_prevent_system_coa_delete
before delete
on public.chart_of_accounts
for each row
execute function public.prevent_system_coa_delete();


-- ============================================================
-- 8. PREVENT SYSTEM ACCOUNT CODE DUPLICATION
-- ============================================================

create unique index if not exists
ux_coa_company_account_code
on public.chart_of_accounts (
    company_id,
    account_code
);


-- ============================================================
-- 9. FINAL COMMENTS
-- ============================================================

comment on function public.next_coa_account_code(
    uuid,
    uuid
)
is
    'Generates the next available Chart of Accounts code within a company and optional parent.';


comment on function public.create_coa_account(
    uuid,
    varchar,
    uuid,
    uuid,
    text,
    uuid,
    public.account_role,
    boolean,
    varchar,
    boolean
)
is
    'Creates a controlled non-system Chart of Accounts account or subaccount.';


comment on function public.update_coa_account(
    uuid,
    varchar,
    text,
    uuid,
    varchar
)
is
    'Updates a non-system Chart of Accounts account.';


comment on function public.set_coa_account_active(
    uuid,
    boolean
)
is
    'Activates or deactivates a non-system Chart of Accounts account.';


comment on function public.move_coa_account(
    uuid,
    uuid
)
is
    'Moves a non-system Chart of Accounts account to a new header parent while preventing circular hierarchies.';


comment on function public.coa_account_can_post(
    uuid
)
is
    'Returns whether an account is currently eligible for manual journal posting.';


-- ============================================================
-- END MIGRATION 017
-- ============================================================