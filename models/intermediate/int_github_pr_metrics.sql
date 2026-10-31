with stg_prs as (
    select * from {{ ref('stg_github_prs') }}
),

calculated as (
    select
        pr_id,
        pr_number,
        title,
        state,
        author_username,
        is_locked,
        created_at,
        closed_at,
        merged_at,
        pr_url,
        head_branch,
        base_branch,

        -- Calculate lifecycle metrics
        case 
            when closed_at is not null and created_at is not null 
            then epoch(closed_at - created_at) / 3600.0 
            else null 
        end as hours_to_close,

        case 
            when merged_at is not null and created_at is not null 
            then epoch(merged_at - created_at) / 3600.0 
            else null 
        end as hours_to_merge,

        -- Simple categorical flags
        case
            when merged_at is not null then 'merged'
            when state = 'closed' then 'closed_unmerged'
            else 'open'
        end as pr_resolution_status

    from stg_prs
)

select * from calculated