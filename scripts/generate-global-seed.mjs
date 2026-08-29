import fs from 'node:fs'
import path from 'node:path'

import {
  countries,
  languages,
} from 'countries-list'

import {
  currencies,
} from 'countries-list/currencies'

import {
  iso31661,
} from 'iso-3166'


/*
|--------------------------------------------------------------------------
| ELVARIS ERP
| Global Master Seed Generator
|--------------------------------------------------------------------------
|
| Generates:
|
|   supabase/migrations/003_seed_global_masters.sql
|
| Authoritative country identity:
|
|   ISO 3166-1 assigned countries
|
| Country fields:
|
|   name
|   ISO alpha-2
|   ISO alpha-3
|   ISO numeric
|   phone code
|   default currency
|
| Currency fields:
|
|   ISO alphabetic code
|   ISO numeric code
|   symbol
|   decimal places
|
| Other universal masters:
|
|   Languages
|   Units of Measure
|   Payment Terms
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


function formatNumericCode(value) {
  if (
    value === null ||
    value === undefined ||
    value === ''
  ) {
    return null
  }

  return String(value).padStart(
    3,
    '0',
  )
}


/*
|--------------------------------------------------------------------------
| ISO 3166-1 COUNTRY DATA
|--------------------------------------------------------------------------
|
| iso31661 contains currently assigned
| ISO 3166-1 entries.
|
| Reserved entries such as AC are excluded
| automatically because they are not part of
| the assigned-country list.
|--------------------------------------------------------------------------
*/

const isoCountryEntries =
  iso31661
    .filter(
      (country) =>
        country.state === 'assigned',
    )
    .map(
      (country) => ({
        alpha2:
          String(
            country.alpha2,
          ).toUpperCase(),

        alpha3:
          country.alpha3
            ? String(
                country.alpha3,
              ).toUpperCase()
            : null,

        numeric:
          formatNumericCode(
            country.numeric,
          ),

        name:
          country.name,
      }),
    )
    .filter(
      (country) =>
        country.alpha2 &&
        country.alpha3 &&
        country.numeric &&
        country.name,
    )
    .sort(
      (a, b) =>
        a.name.localeCompare(
          b.name,
        ),
    )


/*
|--------------------------------------------------------------------------
| Build ISO alpha-2 lookup
|--------------------------------------------------------------------------
*/

const isoCountryByAlpha2 =
  new Map(
    isoCountryEntries.map(
      (country) => [
        country.alpha2,
        country,
      ],
    ),
  )


/*
|--------------------------------------------------------------------------
| CURRENCY DATA
|--------------------------------------------------------------------------
*/

const currencyEntries =
  Object.entries(
    currencies,
  )
    .sort(
      ([codeA], [codeB]) =>
        codeA.localeCompare(
          codeB,
        ),
    )


const currencySql =
  currencyEntries
    .map(
      ([code, currency]) => {
        const currencyCode =
          code.toUpperCase()

        const name =
          currency?.name ??
          currencyCode

        const symbol =
          currency?.symbol ??
          currencyCode

        const numericCode =
          formatNumericCode(
            currency?.numeric,
          )

        const decimalPlaces =
          Number.isInteger(
            currency?.decimals,
          )
            ? currency.decimals
            : 2

        return `(
  ${sqlString(
    currencyCode,
  )},
  ${sqlString(name)},
  ${sqlString(symbol)},
  ${sqlString(
    numericCode,
  )},
  ${decimalPlaces},
  true
)`
      },
    )
    .join(',\n')


/*
|--------------------------------------------------------------------------
| COUNTRY DATA
|--------------------------------------------------------------------------
|
| ISO 3166 supplies identity.
| countries-list supplies supplemental phone
| and currency information.
|--------------------------------------------------------------------------
*/

const countryEntries =
  isoCountryEntries.map(
    (isoCountry) => {
      const supplemental =
        countries[
          isoCountry.alpha2
        ]

      const phoneCodes =
        Array.isArray(
          supplemental?.phone,
        )
          ? supplemental.phone
          : []

      const phoneCode =
        phoneCodes.length > 0
          ? `+${phoneCodes[0]}`
          : null

      const sourceCurrencies =
        Array.isArray(
          supplemental?.currency,
        )
          ? supplemental.currency
          : []

      return {
        alpha2:
          isoCountry.alpha2,

        alpha3:
          isoCountry.alpha3,

        numeric:
          isoCountry.numeric,

        name:
          isoCountry.name,

        phoneCode,

        sourceCurrencies,
      }
    },
  )


/*
|--------------------------------------------------------------------------
| COUNTRY SQL
|--------------------------------------------------------------------------
*/

const countrySql =
  countryEntries
    .map(
      (country) => `(
  ${sqlString(
    country.name,
  )},
  ${sqlString(
    country.alpha2,
  )},
  ${sqlString(
    country.alpha3,
  )},
  ${sqlString(
    country.numeric,
  )},
  ${sqlString(
    country.phoneCode,
  )},
  true
)`,
    )
    .join(',\n')


/*
|--------------------------------------------------------------------------
| LANGUAGE DATA
|--------------------------------------------------------------------------
*/

const languageEntries =
  Object.entries(
    languages,
  ).sort(
    ([codeA], [codeB]) =>
      codeA.localeCompare(
        codeB,
      ),
  )


const languageSql =
  languageEntries
    .map(
      ([code, language]) => `(
  ${sqlString(code)},
  ${sqlString(
    language?.name ?? code,
  )},
  true
)`,
    )
    .join(',\n')


/*
|--------------------------------------------------------------------------
| UNITS OF MEASURE
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
| PAYMENT TERMS
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
| COUNTRY DEFAULT CURRENCIES
|--------------------------------------------------------------------------
*/

const countryCurrencyUpdates =
  countryEntries
    .map(
      (country) => {
        if (
          country.sourceCurrencies
            .length === 0
        ) {
          return ''
        }

        const currencyCode =
          String(
            country.sourceCurrencies[0],
          ).toUpperCase()

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
  country.alpha2,
)};`
      },
    )
    .filter(Boolean)
    .join('\n')


/*
|--------------------------------------------------------------------------
| GENERATED SQL MIGRATION
|--------------------------------------------------------------------------
*/

const sql = `-- ============================================================
-- ELVARIS ERP
-- Migration 003: Seed Global Masters
--
-- Generated by:
-- scripts/generate-global-seed.mjs
--
-- Authoritative country source:
-- ISO 3166-1 assigned countries
--
-- Currency source:
-- ISO 4217 dataset from countries-list
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
-- 2. DEACTIVATE LEGACY / NON-ISO COUNTRY RECORDS
--
-- Earlier development seeds contained 252 records.
-- The authoritative assigned ISO 3166-1 list contains
-- the current assigned country entries only.
--
-- We do not delete legacy records because they may later
-- become referenced. We deactivate them instead.
-- ============================================================

update public.countries
set
  is_active = false,
  updated_at = now()
where is_active = true
  and iso2_code not in (
${countryEntries
  .map(
    (country) =>
      `    ${sqlString(
        country.alpha2,
      )}`,
  )
  .join(',\n')}
  );


-- ============================================================
-- 3. COUNTRIES
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
-- 4. LANGUAGES
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
-- 5. UNITS OF MEASURE
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
-- 6. PAYMENT TERMS
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
-- 7. COUNTRY DEFAULT CURRENCIES
-- ============================================================

${countryCurrencyUpdates}


-- ============================================================
-- 8. FINAL VERIFICATION
-- ============================================================

do $$
declare
  currency_count integer;
  country_count integer;
  language_count integer;
  uom_count integer;
  payment_term_count integer;

  missing_iso3 integer;
  missing_numeric integer;
  active_non_iso integer;
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


  select count(*)
  into missing_iso3
  from public.countries
  where is_active = true
    and iso3_code is null;


  select count(*)
  into missing_numeric
  from public.countries
  where is_active = true
    and numeric_code is null;


  select count(*)
  into active_non_iso
  from public.countries
  where is_active = true
    and (
      iso3_code is null
      or numeric_code is null
    );


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


  if missing_iso3 > 0 then
    raise exception
      'Global seed failed: % active countries are missing ISO alpha-3 codes.',
      missing_iso3;
  end if;


  if missing_numeric > 0 then
    raise exception
      'Global seed failed: % active countries are missing ISO numeric codes.',
      missing_numeric;
  end if;


  if active_non_iso > 0 then
    raise exception
      'Global seed failed: % active countries have incomplete ISO identity.',
      active_non_iso;
  end if;


  raise notice
    'Elvaris global seed completed: % currencies, % active countries, % languages, % UOMs, % payment terms.',
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
| WRITE FILE
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
| GENERATOR VALIDATION
|--------------------------------------------------------------------------
*/

const countriesMissingIso3 =
  countryEntries.filter(
    (country) =>
      !country.alpha3,
  )

const countriesMissingNumeric =
  countryEntries.filter(
    (country) =>
      !country.numeric,
  )


if (
  countriesMissingIso3.length >
  0
) {
  throw new Error(
    `Generator failed: ${countriesMissingIso3.length} countries are missing ISO alpha-3 codes.`,
  )
}


if (
  countriesMissingNumeric.length >
  0
) {
  throw new Error(
    `Generator failed: ${countriesMissingNumeric.length} countries are missing ISO numeric codes.`,
  )
}


/*
|--------------------------------------------------------------------------
| SUMMARY
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