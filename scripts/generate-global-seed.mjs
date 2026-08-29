import fs from 'node:fs'
import path from 'node:path'

import {
  countries,
  languages,
} from 'countries-list'

import {
  currencies,
} from 'countries-list/currencies'


/*
|--------------------------------------------------------------------------
| Elvaris Global Master Seed Generator
|--------------------------------------------------------------------------
|
| Generates:
|
|   supabase/migrations/003_seed_global_masters.sql
|
| Universal data:
|
|   Countries
|   Currencies
|   Languages
|   Units of Measure
|   Payment Terms
|
| Country and currency identifiers include:
|
|   Country ISO alpha-2
|   Country ISO alpha-3
|   Country ISO numeric
|   Currency ISO alpha-3
|   Currency ISO numeric
|
| The generated SQL is idempotent.
|--------------------------------------------------------------------------
*/


/*
|--------------------------------------------------------------------------
| SQL helpers
|--------------------------------------------------------------------------
*/

function sqlString(value) {
  if (
    value === null ||
    value === undefined ||
    value === ''
  ) {
    return 'null'
  }

  return `'${String(value)
    .replaceAll("'", "''")}'`
}


function sqlInteger(value) {
  if (
    value === null ||
    value === undefined ||
    value === ''
  ) {
    return 'null'
  }

  const number = Number(value)

  if (!Number.isInteger(number)) {
    return 'null'
  }

  return String(number)
}


/*
|--------------------------------------------------------------------------
| Currency data
|--------------------------------------------------------------------------
*/

const currencyEntries = Object.entries(
  currencies,
).sort(
  ([codeA], [codeB]) =>
    codeA.localeCompare(codeB),
)


const currencySql =
  currencyEntries
    .map(
      ([code, currency]) => {
        const name =
          currency?.name ??
          code

        const symbol =
          currency?.symbol ??
          code

        const numericCode =
          currency?.numeric ??
          currency?.number ??
          currency?.isoNumeric ??
          null

        const decimalPlaces =
          Number.isInteger(
            currency?.decimals,
          )
            ? currency.decimals
            : 2

        return `(
  ${sqlString(code.toUpperCase())},
  ${sqlString(name)},
  ${sqlString(symbol)},
  ${sqlString(
    numericCode === null
      ? null
      : String(numericCode).padStart(
          3,
          '0',
        ),
  )},
  ${decimalPlaces},
  true
)`
      },
    )
    .join(',\n')


/*
|--------------------------------------------------------------------------
| Country data
|--------------------------------------------------------------------------
*/

const countryEntries =
  Object.entries(countries).sort(
    ([, countryA], [, countryB]) =>
      String(
        countryA?.name ?? '',
      ).localeCompare(
        String(
          countryB?.name ?? '',
        ),
      ),
  )


const countrySql =
  countryEntries
    .map(
      ([iso2, country]) => {
        const alpha2 =
          iso2.toUpperCase()

        const alpha3 =
          country?.iso3 ??
          country?.alpha3 ??
          null

        const numeric =
          country?.numeric ??
          country?.isoNumeric ??
          null

        const phoneCodes =
          Array.isArray(
            country?.phone,
          )
            ? country.phone
            : []

        const phoneCode =
          phoneCodes.length > 0
            ? `+${phoneCodes[0]}`
            : null

        return `(
  ${sqlString(
    country?.name ?? alpha2,
  )},
  ${sqlString(alpha2)},
  ${sqlString(
    alpha3
      ? String(alpha3).toUpperCase()
      : null,
  )},
  ${sqlString(
    numeric === null
      ? null
      : String(numeric).padStart(
          3,
          '0',
        ),
  )},
  ${sqlString(phoneCode)},
  true
)`
      },
    )
    .join(',\n')


/*
|--------------------------------------------------------------------------
| Language data
|--------------------------------------------------------------------------
*/

const languageEntries =
  Object.entries(
    languages,
  ).sort(
    ([codeA], [codeB]) =>
      codeA.localeCompare(codeB),
  )


const languageSql =
  languageEntries
    .map(
      ([code, language]) => {
        return `(
  ${sqlString(code)},
  ${sqlString(
    language?.name ?? code,
  )},
  true
)`
      },
    )
    .join(',\n')


/*
|--------------------------------------------------------------------------
| Universal Units of Measure
|--------------------------------------------------------------------------
*/

const uomSeed = [
  [
    'PCS',
    'Pieces',
    'pcs',
    'quantity',
  ],
  [
    'KG',
    'Kilogram',
    'kg',
    'weight',
  ],
  [
    'G',
    'Gram',
    'g',
    'weight',
  ],
  [
    'TON',
    'Metric Ton',
    't',
    'weight',
  ],
  [
    'LB',
    'Pound',
    'lb',
    'weight',
  ],
  [
    'M',
    'Meter',
    'm',
    'length',
  ],
  [
    'CM',
    'Centimeter',
    'cm',
    'length',
  ],
  [
    'MM',
    'Millimeter',
    'mm',
    'length',
  ],
  [
    'KM',
    'Kilometer',
    'km',
    'length',
  ],
  [
    'FT',
    'Foot',
    'ft',
    'length',
  ],
  [
    'IN',
    'Inch',
    'in',
    'length',
  ],
  [
    'L',
    'Liter',
    'L',
    'volume',
  ],
  [
    'ML',
    'Milliliter',
    'ml',
    'volume',
  ],
  [
    'M2',
    'Square Meter',
    'm²',
    'area',
  ],
  [
    'M3',
    'Cubic Meter',
    'm³',
    'volume',
  ],
  [
    'BOX',
    'Box',
    'box',
    'packaging',
  ],
  [
    'PACK',
    'Pack',
    'pack',
    'packaging',
  ],
  [
    'DOZ',
    'Dozen',
    'doz',
    'quantity',
  ],
]


const uomSql =
  uomSeed
    .map(
      ([
        code,
        name,
        abbreviation,
        type,
      ]) => `(
  ${sqlString(code)},
  ${sqlString(name)},
  ${sqlString(abbreviation)},
  ${sqlString(type)},
  1,
  true
)`,
    )
    .join(',\n')


/*
|--------------------------------------------------------------------------
| Payment Terms
|--------------------------------------------------------------------------
*/

const paymentTermsSeed = [
  [
    'COD',
    'Cash on Delivery',
    0,
    'Payment is due immediately.',
  ],
  [
    'NET7',
    'Net 7',
    7,
    'Payment due within 7 days.',
  ],
  [
    'NET15',
    'Net 15',
    15,
    'Payment due within 15 days.',
  ],
  [
    'NET30',
    'Net 30',
    30,
    'Payment due within 30 days.',
  ],
  [
    'NET45',
    'Net 45',
    45,
    'Payment due within 45 days.',
  ],
  [
    'NET60',
    'Net 60',
    60,
    'Payment due within 60 days.',
  ],
  [
    'NET90',
    'Net 90',
    90,
    'Payment due within 90 days.',
  ],
]


const paymentTermsSql =
  paymentTermsSeed
    .map(
      ([
        code,
        name,
        daysDue,
        description,
      ]) => `(
  ${sqlString(code)},
  ${sqlString(name)},
  ${daysDue},
  ${sqlString(description)},
  true
)`,
    )
    .join(',\n')


/*
|--------------------------------------------------------------------------
| Default country → currency mappings
|--------------------------------------------------------------------------
|
| The source package can provide one or more currencies.
| We use the first listed currency as the default where
| it exists in our currency master.
|--------------------------------------------------------------------------
*/

const countryCurrencyUpdates =
  countryEntries
    .map(
      ([iso2, country]) => {
        const listedCurrencies =
          Array.isArray(
            country?.currency,
          )
            ? country.currency
            : []

        const currencyCode =
          listedCurrencies.length > 0
            ? String(
                listedCurrencies[0],
              ).toUpperCase()
            : null

        if (!currencyCode) {
          return ''
        }

        return `update public.countries
set
  default_currency_id = (
    select id
    from public.currencies
    where code = ${sqlString(
      currencyCode,
    )}
    limit 1
  ),
  updated_at = now()
where iso2_code = ${sqlString(
    iso2.toUpperCase(),
  )};`
      },
    )
    .filter(Boolean)
    .join('\n')


/*
|--------------------------------------------------------------------------
| Generate SQL
|--------------------------------------------------------------------------
*/

const sql = `-- ============================================================
-- ELVARIS ERP
-- Migration 003: Seed Global Masters
--
-- Generated by:
-- scripts/generate-global-seed.mjs
--
-- Universal data:
--   Countries
--   Currencies
--   Languages
--   Units of Measure
--   Payment Terms
--
-- This migration is idempotent.
-- ============================================================


-- ============================================================
-- 1. CURRENCIES
-- ============================================================

insert into public.currencies (
  code,
  name,
  symbol,
  numeric_code,
  decimal_places,
  is_active
)
values
${currencySql}
on conflict (code)
do update set
  name = excluded.name,
  symbol = excluded.symbol,
  numeric_code = excluded.numeric_code,
  decimal_places = excluded.decimal_places,
  is_active = true,
  updated_at = now();


-- ============================================================
-- 2. COUNTRIES
-- ============================================================

insert into public.countries (
  name,
  iso2_code,
  iso3_code,
  numeric_code,
  phone_code,
  is_active
)
values
${countrySql}
on conflict (iso2_code)
do update set
  name = excluded.name,
  iso3_code = excluded.iso3_code,
  numeric_code = excluded.numeric_code,
  phone_code = excluded.phone_code,
  is_active = true,
  updated_at = now();


-- ============================================================
-- 3. LANGUAGES
-- ============================================================

insert into public.languages (
  code,
  name,
  is_active
)
values
${languageSql}
on conflict (code)
do update set
  name = excluded.name,
  is_active = true,
  updated_at = now();


-- ============================================================
-- 4. UNITS OF MEASURE
-- ============================================================

insert into public.units_of_measure (
  code,
  name,
  abbreviation,
  uom_type,
  conversion_factor,
  is_active
)
values
${uomSql}
on conflict (code)
do update set
  name = excluded.name,
  abbreviation = excluded.abbreviation,
  uom_type = excluded.uom_type,
  conversion_factor = excluded.conversion_factor,
  is_active = true,
  updated_at = now();


-- ============================================================
-- 5. PAYMENT TERMS
-- ============================================================

insert into public.payment_terms (
  code,
  name,
  days_due,
  description,
  is_active
)
values
${paymentTermsSql}
on conflict (code)
do update set
  name = excluded.name,
  days_due = excluded.days_due,
  description = excluded.description,
  is_active = true,
  updated_at = now();


-- ============================================================
-- 6. COUNTRY DEFAULT CURRENCIES
-- ============================================================

${countryCurrencyUpdates}


-- ============================================================
-- 7. VERIFICATION
-- ============================================================

do $$
declare
  currency_count integer;
  country_count integer;
  language_count integer;
  uom_count integer;
  payment_term_count integer;
begin

  select count(*)
  into currency_count
  from public.currencies
  where is_active = true;

  select count(*)
  into country_count
  from public.countries
  where is_active = true;

  select count(*)
  into language_count
  from public.languages
  where is_active = true;

  select count(*)
  into uom_count
  from public.units_of_measure
  where is_active = true;

  select count(*)
  into payment_term_count
  from public.payment_terms
  where is_active = true;


  if currency_count = 0 then
    raise exception
      'Global seed failed: no active currencies found.';
  end if;

  if country_count = 0 then
    raise exception
      'Global seed failed: no active countries found.';
  end if;

  if language_count = 0 then
    raise exception
      'Global seed failed: no active languages found.';
  end if;

  if uom_count = 0 then
    raise exception
      'Global seed failed: no active units of measure found.';
  end if;

  if payment_term_count = 0 then
    raise exception
      'Global seed failed: no active payment terms found.';
  end if;


  raise notice
    'Elvaris global seed completed: % currencies, % countries, % languages, % UOMs, % payment terms.',
    currency_count,
    country_count,
    language_count,
    uom_count,
    payment_term_count;

end
$$;
`


/*
|--------------------------------------------------------------------------
| Write migration file
|--------------------------------------------------------------------------
*/

const outputDirectory =
  path.resolve(
    'supabase',
    'migrations',
  )

const outputFile =
  path.join(
    outputDirectory,
    '003_seed_global_masters.sql',
  )


fs.mkdirSync(
  outputDirectory,
  {
    recursive: true,
  },
)

fs.writeFileSync(
  outputFile,
  sql,
  'utf8',
)


/*
|--------------------------------------------------------------------------
| Console summary
|--------------------------------------------------------------------------
*/

console.log(
  `Generated: ${outputFile}`,
)

console.log(
  `Currencies: ${currencyEntries.length}`,
)

console.log(
  `Countries: ${countryEntries.length}`,
)

console.log(
  `Languages: ${languageEntries.length}`,
)

console.log(
  `UOMs: ${uomSeed.length}`,
)

console.log(
  `Payment terms: ${paymentTermsSeed.length}`,
)