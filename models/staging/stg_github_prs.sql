with source as (
    select * from raw_github_prs
),

cleaned as (
    select
        -- Identifiers
        cast(raw_payload->>'$.id' as bigint) as pr_id,
        cast(raw_payload->>'$.number' as integer) as pr_number,
        raw_payload->>'$.node_id' as node_id,

        -- Status & Metadata
        raw_payload->>'$.title' as title,
        raw_payload->>'$.state' as state,
        coalesce(cast(raw_payload->>'$.locked' as boolean), false) as is_locked,

        -- User / Author
        raw_payload->'user'->>'login' as author_username,
        cast(raw_payload->'user'->>'id' as bigint) as author_id,

        -- Timestamps
        cast(raw_payload->>'$.created_at' as timestamp) as created_at,
        cast(raw_payload->>'$.updated_at' as timestamp) as updated_at,
        cast(raw_payload->>'$.closed_at' as timestamp) as closed_at,
        cast(raw_payload->>'$.merged_at' as timestamp) as merged_at,

        -- URLs & Branches
        raw_payload->>'$.html_url' as pr_url,
        raw_payload->'head'->>'ref' as head_branch,
        raw_payload->'base'->>'ref' as base_branch,

        -- Audit / Loading timestamp
        loaded_at

    from source
)

select * from cleaned