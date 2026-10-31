with int_prs as (
    select * from {{ ref('int_github_pr_metrics') }}
),

author_summary as (
    select
        author_username,
        count(*) as total_prs,
        sum(case when pr_resolution_status = 'merged' then 1 else 0 end) as merged_prs,
        sum(case when pr_resolution_status = 'closed_unmerged' then 1 else 0 end) as closed_unmerged_prs,
        round(avg(hours_to_merge), 2) as avg_hours_to_merge,
        min(created_at) as first_pr_seen,
        max(created_at) as latest_pr_seen

    from int_prs
    where author_username is not null
    group by 1
)

select * from author_summary
order by total_prs desc