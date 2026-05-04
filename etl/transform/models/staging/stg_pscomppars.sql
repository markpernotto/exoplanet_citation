{{
    config(
        materialized='view'
    )
}}

with source as (

    select * from {{ source('raw', 'planets_snapshots') }}

),

current_snapshot as (

    select *
    from source
    where snapshot_date = (select max(snapshot_date) from source)

)

select
    pl_name,
    hostname,
    sy_snum,
    sy_pnum,
    discoverymethod,
    disc_year,
    disc_facility,
    disc_telescope,
    disc_instrument,
    disc_refname,
    pl_orbper,
    pl_rade,
    pl_bmasse,
    pl_eqt,
    st_dist,
    snapshot_date,
    source_url,
    source_retrieved_at,
    source_checksum,
    extraction_version
from current_snapshot
