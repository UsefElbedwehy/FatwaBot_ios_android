-- Add the response contract's version to the answer cache key.
--
-- Caught by deploying the M5.1 structured contract and watching the very first
-- request come back in 0.96s with the *old* flat shape: the cache had a stored
-- response for that question and happily served it. 0046's key covers what can
-- change the answer's *content* — question, mode, model, corpus generation —
-- but not what can change its *shape*. A contract change is exactly that, and
-- it would have shipped a mixture of old and new response bodies to clients
-- depending on who had asked what before the deploy.
--
-- Defaulting existing rows to 1 while the code writes 2 invalidates every
-- pre-M5.1 entry without a delete: they simply stop matching.

alter table fatwa.answer_cache
    add column if not exists contract_version integer not null default 1;

alter table fatwa.answer_cache
    drop constraint if exists answer_cache_pkey;

alter table fatwa.answer_cache
    add primary key (app_id, question_hash, mode, model, contract_version);
