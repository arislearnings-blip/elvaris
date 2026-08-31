-- ============================================================
-- ELVARIS ERP
-- Migration 029
-- Accounting Name / Account Integrity
-- ============================================================
--
-- Purpose:
--   Enforce the correct Accounting Name Type for subledger
--   controlled accounts.
--
-- Rules:
--
--   Accounts Receivable
--       -> Customer
--
--   Accounts Payable
--       -> Vendor
--
--   Owner Equity / Owner Draw
--       -> Customer / Vendor is not appropriate.
--          These remain configurable for future employee /
--          other-party usage.
--
-- Ordinary accounts
--       -> Name remains optional.
--
-- This is intentionally implemented at posting-validation
-- level rather than forcing every journal line to have a Name.
-- ============================================================


-- ============================================================
-- 1. ACCOUNT NAME TYPE RULE FUNCTION
-- ============================================================

create or replace function public.get_account_required_name_type(
    p_account_id uuid
)
returns public.accounting_name_type
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_system_code varchar(60);
    v_name_type public.accounting_name_type;
begin

    select
        system_account_code
    into v_system_code
    from public.chart_of_accounts
    where id = p_account_id;


    if not found then

        raise exception
            'Account does not exist.';

    end if;


    v_name_type :=
        case v_system_code

            when 'accounts_receivable'
                then 'customer'::public.accounting_name_type

            when 'accounts_payable'
                then 'vendor'::public.accounting_name_type

            else null

        end;


    return v_name_type;

end;
$function$;


-- ============================================================
-- 2. VALIDATE NAME TYPE FOR JOURNAL LINE
-- ============================================================

create or replace function public.validate_journal_line_name_type(
    p_account_id uuid,
    p_name_id uuid
)
returns boolean
language plpgsql
security definer
stable
set search_path = public
as $function$

declare
    v_required_type public.accounting_name_type;
    v_actual_type public.accounting_name_type;
begin

    if p_name_id is null then
        return true;
    end if;


    v_required_type :=
        public.get_account_required_name_type(
            p_account_id
        );


    if v_required_type is null then
        return true;
    end if;


    select
        name_type
    into v_actual_type
    from public.accounting_names
    where id = p_name_id;


    if not found then

        raise exception
            'Accounting Name does not exist.';

    end if;


    if v_actual_type <> v_required_type then

        raise exception
            'The selected account requires a "%" Name, but the selected Name is "%".',
            v_required_type,
            v_actual_type;

    end if;


    return true;

end;
$function$;


-- ============================================================
-- 3. UPDATE JOURNAL NAME VALIDATION
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
    v_company_id uuid;
begin

    select company_id
    into v_company_id
    from public.journal_entries
    where id = p_journal_entry_id;


    if v_company_id is null then

        raise exception
            'Journal entry does not exist.';

    end if;


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
        order by jel.line_number
    loop

        -- ----------------------------------------------------
        -- Name required
        -- ----------------------------------------------------

        if v_line.name_requirement =
           'required'::public.account_name_requirement
        then

            if v_line.name_id is null then

                raise exception
                    'Journal line % requires a Name for account "%".',
                    v_line.line_number,
                    v_line.account_code;

            end if;

        end if;


        -- ----------------------------------------------------
        -- Name supplied
        -- ----------------------------------------------------

        if v_line.name_id is not null then

            if not exists (
                select 1
                from public.accounting_names an
                where an.id = v_line.name_id
                  and an.company_id = v_company_id
                  and an.is_active = true
            ) then

                raise exception
                    'Journal line % references an invalid or inactive Accounting Name.',
                    v_line.line_number;

            end if;


            perform public.validate_journal_line_name_type(
                v_line.account_id,
                v_line.name_id
            );

        end if;

    end loop;


    return true;

end;
$function$;


-- ============================================================
-- 4. UPDATE GRID REPLACEMENT VALIDATION
-- ============================================================

create or replace function public.replace_draft_journal_lines(
    p_journal_entry_id uuid,
    p_lines jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_entry public.journal_entries%rowtype;

    v_line jsonb;

    v_line_number integer := 0;

    v_account_id uuid;
    v_name_id uuid;
    v_branch_id uuid;
    v_department_id uuid;

    v_description text;

    v_debit numeric(20,6);
    v_credit numeric(20,6);

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


    if v_entry.status <>
       'draft'::public.journal_entry_status
    then

        raise exception
            'Only draft journal entries can be edited.';

    end if;


    if p_lines is null
       or jsonb_typeof(p_lines) <> 'array'
    then

        raise exception
            'Journal grid lines must be supplied as a JSON array.';

    end if;


    delete from public.journal_entry_lines
    where journal_entry_id = p_journal_entry_id;


    for v_line in
        select value
        from jsonb_array_elements(p_lines)
    loop

        v_line_number :=
            v_line_number + 1;


        -- ----------------------------------------------------
        -- Account
        -- ----------------------------------------------------

        if nullif(
            v_line->>'account_id',
            ''
        ) is null then

            raise exception
                'Journal grid line % has no Account.',
                v_line_number;

        end if;


        v_account_id :=
            (v_line->>'account_id')::uuid;


        perform public.validate_journal_account(
            v_account_id
        );


        if not exists (
            select 1
            from public.chart_of_accounts coa
            where coa.id = v_account_id
              and coa.company_id = v_entry.company_id
        ) then

            raise exception
                'Journal grid line % uses an account from another company.',
                v_line_number;

        end if;


        -- ----------------------------------------------------
        -- Name
        -- ----------------------------------------------------

        if nullif(
            v_line->>'name_id',
            ''
        ) is null then

            v_name_id := null;

        else

            v_name_id :=
                (v_line->>'name_id')::uuid;

        end if;


        if public.journal_account_name_required(
            v_account_id
        ) then

            if v_name_id is null then

                raise exception
                    'Journal grid line % requires a Name.',
                    v_line_number;

            end if;

        end if;


        if v_name_id is not null then

            if not exists (
                select 1
                from public.accounting_names an
                where an.id = v_name_id
                  and an.company_id = v_entry.company_id
                  and an.is_active = true
            ) then

                raise exception
                    'Journal grid line % contains an invalid or inactive Name.',
                    v_line_number;

            end if;


            perform public.validate_journal_line_name_type(
                v_account_id,
                v_name_id
            );

        end if;


        -- ----------------------------------------------------
        -- Description
        -- ----------------------------------------------------

        v_description :=
            nullif(
                v_line->>'description',
                ''
            );


        -- ----------------------------------------------------
        -- Debit / Credit
        -- ----------------------------------------------------

        v_debit :=
            coalesce(
                nullif(
                    v_line->>'debit',
                    ''
                )::numeric,
                0
            );


        v_credit :=
            coalesce(
                nullif(
                    v_line->>'credit',
                    ''
                )::numeric,
                0
            );


        if v_debit < 0
           or v_credit < 0
        then

            raise exception
                'Journal grid line % contains a negative amount.',
                v_line_number;

        end if;


        if v_debit > 0
           and v_credit > 0
        then

            raise exception
                'Journal grid line % cannot contain both Debit and Credit.',
                v_line_number;

        end if;


        if v_debit = 0
           and v_credit = 0
        then

            raise exception
                'Journal grid line % must contain Debit or Credit.',
                v_line_number;

        end if;


        -- ----------------------------------------------------
        -- Branch
        -- ----------------------------------------------------

        if nullif(
            v_line->>'branch_id',
            ''
        ) is null then

            v_branch_id := v_entry.branch_id;

        else

            v_branch_id :=
                (v_line->>'branch_id')::uuid;

        end if;


        if v_branch_id is not null then

            if not exists (
                select 1
                from public.branches b
                where b.id = v_branch_id
                  and b.company_id = v_entry.company_id
                  and b.is_active = true
            ) then

                raise exception
                    'Journal grid line % contains an invalid branch.',
                    v_line_number;

            end if;

        end if;


        -- ----------------------------------------------------
        -- Department
        -- ----------------------------------------------------

        if nullif(
            v_line->>'department_id',
            ''
        ) is null then

            v_department_id := null;

        else

            v_department_id :=
                (v_line->>'department_id')::uuid;

        end if;


        if v_department_id is not null then

            if not exists (
                select 1
                from public.departments d
                where d.id = v_department_id
                  and d.company_id = v_entry.company_id
                  and d.is_active = true
            ) then

                raise exception
                    'Journal grid line % contains an invalid department.',
                    v_line_number;

            end if;

        end if;


        -- ----------------------------------------------------
        -- Insert grid line
        -- ----------------------------------------------------

        insert into public.journal_entry_lines (
            journal_entry_id,
            line_number,
            account_id,
            branch_id,
            name_id,
            description,
            debit,
            credit,
            currency_id,
            exchange_rate,
            foreign_debit,
            foreign_credit,
            department_id,
            created_at,
            created_by
        )
        values (
            p_journal_entry_id,
            v_line_number,
            v_account_id,
            v_branch_id,
            v_name_id,
            v_description,
            v_debit,
            v_credit,
            v_entry.currency_id,
            v_entry.exchange_rate,
            0,
            0,
            v_department_id,
            now(),
            auth.uid()
        );

    end loop;


    return v_line_number;

end;
$function$;


-- ============================================================
-- 5. VALIDATION
-- ============================================================

do $$
declare
    v_ar integer;
    v_ap integer;
begin

    select count(*)
    into v_ar
    from public.chart_of_accounts
    where system_account_code = 'accounts_receivable'
      and name_requirement =
          'required'::public.account_name_requirement;


    select count(*)
    into v_ap
    from public.chart_of_accounts
    where system_account_code = 'accounts_payable'
      and name_requirement =
          'required'::public.account_name_requirement;


    if v_ar = 0 then

        raise exception
            'Accounts Receivable Name requirement is not configured.';

    end if;


    if v_ap = 0 then

        raise exception
            'Accounts Payable Name requirement is not configured.';

    end if;

end
$$;


-- ============================================================
-- 6. DOCUMENTATION
-- ============================================================

comment on function public.get_account_required_name_type(
    uuid
)
is
    'Returns the required accounting Name type for subledger-controlled accounts.';


comment on function public.validate_journal_line_name_type(
    uuid,
    uuid
)
is
    'Ensures an Accounting Name is compatible with the selected account.';


-- ============================================================
-- END MIGRATION 029
-- ============================================================