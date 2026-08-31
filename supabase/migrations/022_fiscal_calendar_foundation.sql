-- ============================================================
-- ELVARIS ERP
-- Migration 022
-- Fiscal Calendar Foundation
-- ============================================================

-- ============================================================
-- 1. COMPANY FISCAL-YEAR START MONTH
-- ============================================================

alter table public.companies
add column if not exists
    fiscal_year_start_month smallint not null default 7;


alter table public.companies
drop constraint if exists
    companies_fiscal_year_start_month_check;


alter table public.companies
add constraint
    companies_fiscal_year_start_month_check
check (
    fiscal_year_start_month between 1 and 12
);


-- ============================================================
-- 2. CREATE FISCAL YEAR + 12 ACCOUNTING PERIODS
-- ============================================================

create or replace function public.create_company_fiscal_year(
    p_company_id uuid,
    p_start_date date,
    p_name varchar(100) default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$

declare

    v_fiscal_year_id uuid;

    v_end_date date;

    v_fiscal_name varchar(100);

    v_period_start date;

    v_period_end date;

    v_period_number smallint;

begin

    -- ========================================================
    -- COMPANY
    -- ========================================================

    if not exists (
        select 1
        from public.companies c
        where c.id = p_company_id
          and c.is_active = true
    ) then

        raise exception
            'Active company does not exist.';

    end if;


    if p_start_date is null then

        raise exception
            'Fiscal year start date is required.';

    end if;


    -- ========================================================
    -- PREVENT OVERLAPPING FISCAL YEARS
    -- ========================================================

    if exists (
        select 1
        from public.fiscal_years fy
        where fy.company_id = p_company_id
          and p_start_date between
              fy.start_date
              and fy.end_date
    ) then

        raise exception
            'A fiscal year already exists covering date %.',
            p_start_date;

    end if;


    -- ========================================================
    -- ONE-YEAR RANGE
    -- ========================================================

    v_end_date :=
        p_start_date
        + interval '1 year'
        - interval '1 day';


    v_fiscal_name :=
        coalesce(
            nullif(trim(p_name), ''),
            to_char(
                p_start_date,
                'YYYY'
            )
            || '/'
            ||
            to_char(
                v_end_date,
                'YYYY'
            )
        );


    -- ========================================================
    -- CREATE FISCAL YEAR
    -- ========================================================

    insert into public.fiscal_years (
        company_id,
        name,
        start_date,
        end_date,
        is_current,
        status,
        created_at,
        created_by,
        updated_at,
        updated_by
    )
    values (
        p_company_id,
        v_fiscal_name,
        p_start_date,
        v_end_date,
        false,
        'open'::public.fiscal_year_status,
        now(),
        auth.uid(),
        now(),
        auth.uid()
    )
    returning id
    into v_fiscal_year_id;


    -- ========================================================
    -- CREATE 12 MONTHLY ACCOUNTING PERIODS
    -- ========================================================

    for v_period_number in 1..12
    loop

        v_period_start :=
            (
                p_start_date
                + (
                    (v_period_number - 1)
                    * interval '1 month'
                )
            )::date;


        v_period_end :=
            (
                v_period_start
                + interval '1 month'
                - interval '1 day'
            )::date;


        if v_period_number = 12 then

            v_period_end := v_end_date;

        end if;


        insert into public.accounting_periods (
            fiscal_year_id,
            period_number,
            name,
            start_date,
            end_date,
            status,
            created_at,
            updated_at
        )
        values (
            v_fiscal_year_id,
            v_period_number,
            to_char(
                v_period_start,
                'FMMonth'
            ),
            v_period_start,
            v_period_end,
            'open'::public.accounting_period_status,
            now(),
            now()
        );

    end loop;


    -- ========================================================
    -- MARK AS CURRENT FISCAL YEAR
    -- ========================================================

    update public.fiscal_years
    set
        is_current = false,
        updated_at = now(),
        updated_by = auth.uid()
    where company_id = p_company_id
      and id <> v_fiscal_year_id;


    update public.fiscal_years
    set
        is_current = true,
        updated_at = now(),
        updated_by = auth.uid()
    where id = v_fiscal_year_id;


    return v_fiscal_year_id;

end;
$function$;


-- ============================================================
-- 3. INITIALIZE CURRENT FISCAL YEAR FOR COMPANIES
-- ============================================================
--
-- Only companies with NO fiscal year are initialized.
--
-- Fiscal year start is determined from the company's configured
-- fiscal_year_start_month.
--
-- Example:
--
--   start month = 7
--   current date = Aug 2026
--
--   fiscal year = 2026-07-01 through 2027-06-30
--
-- ============================================================

do $block$

declare

    v_company record;

    v_year integer;

    v_start_date date;

begin

    for v_company in
        select
            c.id,
            c.company_code,
            c.fiscal_year_start_month
        from public.companies c
        where c.is_active = true
          and not exists (
              select 1
              from public.fiscal_years fy
              where fy.company_id = c.id
          )
        order by c.company_code
    loop

        v_year :=
            extract(
                year
                from current_date
            )::integer;


        if extract(
            month
            from current_date
        )::integer
        <
        v_company.fiscal_year_start_month
        then

            v_year :=
                v_year - 1;

        end if;


        v_start_date :=
            make_date(
                v_year,
                v_company.fiscal_year_start_month,
                1
            );


        perform public.create_company_fiscal_year(
            v_company.id,
            v_start_date,
            null
        );

    end loop;

end
$block$;


-- ============================================================
-- 4. VALIDATION
-- ============================================================

do $validation$

declare

    v_company record;

    v_fiscal_year_count integer;

    v_period_count integer;

begin

    for v_company in
        select
            id,
            company_code
        from public.companies
        where is_active = true
    loop

        select count(*)
        into v_fiscal_year_count
        from public.fiscal_years fy
        where fy.company_id = v_company.id;


        if v_fiscal_year_count = 0 then

            raise exception
                'No fiscal year exists for company "%".',
                v_company.company_code;

        end if;


        select count(*)
        into v_period_count
        from public.accounting_periods ap
        join public.fiscal_years fy
            on fy.id = ap.fiscal_year_id
        where fy.company_id = v_company.id;


        if v_period_count = 0 then

            raise exception
                'No accounting periods exist for company "%".',
                v_company.company_code;

        end if;


        if v_period_count <> v_fiscal_year_count * 12 then

            raise exception
                'Company "%" does not have exactly 12 accounting periods per fiscal year.',
                v_company.company_code;

        end if;


        if not exists (
            select 1
            from public.fiscal_years fy
            where fy.company_id = v_company.id
              and fy.is_current = true
              and fy.status = 'open'::public.fiscal_year_status
        ) then

            raise exception
                'Company "%" has no current open fiscal year.',
                v_company.company_code;

        end if;

    end loop;

end
$validation$;


-- ============================================================
-- 5. COMMENTS
-- ============================================================

comment on column public.companies.fiscal_year_start_month
is
    'Month in which the company fiscal year begins; 7 represents July.';


comment on function public.create_company_fiscal_year(
    uuid,
    date,
    varchar
)
is
    'Creates one company fiscal year and twelve monthly accounting periods.';