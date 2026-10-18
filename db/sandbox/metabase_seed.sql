-- Metabase Sandbox DB
-- Run this against a fresh Postgres DB added as a separate data source in Metabase.
-- Safe to re-run: truncates before re-inserting.
--
-- Tables mirror the real warehouse schema exactly so Question 1329 (and its
-- sandbox duplicate) can run against both sources without modification.

create schema if not exists warehouse;

-- ── Schema ───────────────────────────────────────────────────────────────────

create table if not exists warehouse.member_journey (
  "Member Identification Number"    text primary key,
  "Email ID of the Member"          text not null,
  "Country"                         text,
  "Status -Income Share Agreement"  text,
  "Contract_Signed?"                text
);

create table if not exists warehouse.transaction (
  id                                serial primary key,
  "Member Identification Number"    text references warehouse.member_journey("Member Identification Number"),
  "Type of Payment"                 text,
  "Amount"                          numeric(12, 2)
);

-- ── Reset ────────────────────────────────────────────────────────────────────

truncate warehouse.transaction restart identity cascade;
truncate warehouse.member_journey restart identity cascade;

-- ── Members ──────────────────────────────────────────────────────────────────

insert into warehouse.member_journey values
  -- Active: contract signed, has both repayments and PEI disbursement
  ('CID-001', 'alice@sandbox.dev',   'Kenya',    'Active',       'Yes'),
  -- Active: repaying, no PEI disbursement yet
  ('CID-002', 'bob@sandbox.dev',     'Rwanda',   'Active',       'Yes'),
  -- Completed: fully repaid
  ('CID-003', 'carol@sandbox.dev',   'Kenya',    'Completed',    'Yes'),
  -- In Arrears: behind on payments
  ('CID-004', 'dan@sandbox.dev',     'Uganda',   'In Arrears',   'Yes'),
  -- Grace Period: contract signed, repayments not yet due
  ('CID-005', 'eve@sandbox.dev',     'Rwanda',   'Grace Period', 'Yes'),
  -- Active: contract signed, zero transactions (edge case)
  ('CID-006', 'frank@sandbox.dev',   'Kenya',    'Active',       'Yes'),
  -- Application: no contract, no transactions
  ('CID-007', 'grace@sandbox.dev',   'Kenya',    'Application',  'No'),
  -- Application: different country
  ('CID-008', 'henry@sandbox.dev',   'Uganda',   'Application',  'No');

-- ── Transactions ─────────────────────────────────────────────────────────────

insert into warehouse.transaction ("Member Identification Number", "Type of Payment", "Amount") values
  -- CID-001: active, repaying + PEI received
  ('CID-001', 'Repayment',   500.00),
  ('CID-001', 'Repayment',   500.00),
  ('CID-001', 'PEI Payment', 12000.00),
  -- CID-002: active, repaying only (no PEI row yet)
  ('CID-002', 'Repayment',   300.00),
  ('CID-002', 'Repayment',   300.00),
  -- CID-003: completed, multiple repayments + PEI
  ('CID-003', 'Repayment',   750.00),
  ('CID-003', 'Repayment',   750.00),
  ('CID-003', 'Repayment',   750.00),
  ('CID-003', 'PEI Payment', 15000.00),
  -- CID-004: in arrears, minimal repayment + PEI disbursed
  ('CID-004', 'Repayment',   100.00),
  ('CID-004', 'PEI Payment', 10000.00),
  -- CID-005: grace period, PEI disbursed but no repayments yet
  ('CID-005', 'PEI Payment', 11000.00);
  -- CID-006: contract signed, zero transactions  (intentional — tests null aggregates)
  -- CID-007, CID-008: application stage, zero transactions (intentional)
