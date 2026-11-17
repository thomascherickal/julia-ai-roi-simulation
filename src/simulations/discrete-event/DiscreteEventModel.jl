# Paradigm 4: Discrete Event Simulation (DES)
# Step-by-step process queues, service stages, and resource limits across the 4 departments.
# Pinpoints exact cycle time saved, queue wait-time changes, and human-in-the-loop verification bottlenecks.

struct DESWorkflowSpec
    team_id::String
    team_name::String
    work_unit_name::String
    monthly_arrivals_per_fte::Float64
    baseline_draft_hours::Float64
    baseline_qa_hours::Float64
    qa_specialist_share::Float64 # Fraction of team capacity dedicated to review/verification/sign-off
    sla_target_hours::Float64
end

const DEFAULT_DES_WORKFLOWS = [
    DESWorkflowSpec("software_eng", "Product & Software Engineering", "Pull Requests & Feature Specs", 14.0, 7.2, 2.1, 0.24, 36.0),
    DESWorkflowSpec("customer_ops", "Customer Support & Success Ops", "Tier-2/3 Escalation Cases", 85.0, 1.25, 0.35, 0.22, 8.0),
    DESWorkflowSpec("sales_gtm", "Enterprise Sales, RevOps & Marketing", "RFPs & Custom Deal Proposals", 18.0, 5.5, 1.6, 0.22, 28.0),
    DESWorkflowSpec("legal_finance", "Legal, Finance & Risk Operations", "Contract Redlines & Audit Memos", 16.0, 6.2, 2.5, 0.30, 48.0)
]

"""
    simulate_stage_queue(rng::AbstractRNG, n_items::Int, n_servers::Int, mean_service_hrs::Float64, arrival_rate_per_hr::Float64)

Simulates a multi-server process stage over a monthly work window using discrete-event server availability tracking (`server_free_time`).
Returns `(avg_wait_hrs, avg_service_hrs, p90_wait_hrs, utilization_pct)`.
"""
function simulate_stage_queue(
    rng::AbstractRNG,
    n_items::Int,
    n_servers::Int,
    mean_service_hrs::Float64,
    arrival_rate_per_hr::Float64
)
    if n_items <= 0 || n_servers <= 0
        return (0.0, mean_service_hrs, 0.0, 0.0)
    end

    # Track when each parallel server becomes free
    server_free_time = zeros(Float64, n_servers)
    wait_times = Vector{Float64}(undef, n_items)
    service_times = Vector{Float64}(undef, n_items)

    current_time = 0.0
    for k in 1:n_items
        # Exponential inter-arrival time
        inter_arrival = -log(max(1e-9, rand(rng))) / max(1e-6, arrival_rate_per_hr)
        current_time += inter_arrival

        # Assign to earliest available server (min-heap / argmin)
        best_srv = 1
        earliest_free = server_free_time[1]
        @inbounds for s in 2:n_servers
            if server_free_time[s] < earliest_free
                earliest_free = server_free_time[s]
                best_srv = s
            end
        end

        start_service = max(current_time, earliest_free)
        wait_t = start_service - current_time

        # Erlang-2 / Gamma-like realistic task service time (less noisy than pure exponential)
        u1 = max(1e-9, rand(rng))
        u2 = max(1e-9, rand(rng))
        svc_t = -0.5 * mean_service_hrs * (log(u1) + log(u2))

        server_free_time[best_srv] = start_service + svc_t
        wait_times[k] = wait_t
        service_times[k] = svc_t
    end

    total_busy = sum(service_times)
    horizon_span = max(160.0, maximum(server_free_time))
    utilization = clamp((total_busy / (n_servers * horizon_span)) * 100.0, 0.0, 99.8)

    return (
        mean(wait_times),
        mean(service_times),
        quantile(wait_times, 0.90),
        utilization
    )
end

"""
    run_discrete_event_model(config::ScenarioConfig; horizon_months::Int=36, seed::Int=20261118,
                             ai_triage_deflection_boost::Float64=1.0, qa_capacity_reallocation::Float64=0.0)

Simulates a 3-stage discrete-event process pipeline for each department across 36 months:
- Stage 1: AI Triage & Autonomous Resolution (instantaneous agent/copilot assist)
- Stage 2: Human + Copilot Drafting / Execution Queue
- Stage 3: Human-in-the-Loop QA, Code Review & Compliance Sign-off Queue (where bottlenecks form!)
"""
function run_discrete_event_model(
    config::ScenarioConfig;
    horizon_months::Int=36,
    seed::Int=20261118,
    ai_triage_deflection_boost::Float64=1.0,
    qa_capacity_reallocation::Float64=0.0
)
    rng = MersenneTwister(seed)
    n_teams = length(config.teams)
    total_hc = sum(t.headcount for t in config.teams)

    ceiling = config.rollout.ceiling_mode
    t0 = config.rollout.inflection_month_mode
    k_steep = config.rollout.steepness_mode

    # Scenario-specific QA reallocation: pragmatic & agentic re-allocate saved drafting capacity into QA review
    scenario_qa_shift = if qa_capacity_reallocation > 0.0
        qa_capacity_reallocation
    elseif config.id == "agentic_transformation"
        0.07
    elseif config.id == "pragmatic_phased"
        0.05
    elseif config.id == "conservative_pilot"
        0.04
    else
        0.00 # Blitzscale does NOT expand review capacity, triggering a severe Stage-3 bottleneck
    end

    monthly_cycle_time_hrs = zeros(Float64, horizon_months)
    monthly_baseline_cycle_hrs = zeros(Float64, horizon_months)
    monthly_draft_wait_hrs = zeros(Float64, horizon_months)
    monthly_qa_wait_hrs = zeros(Float64, horizon_months)
    monthly_throughput_items = zeros(Float64, horizon_months)
    monthly_hours_saved = zeros(Float64, horizon_months)
    monthly_cum_cashflow = zeros(Float64, horizon_months)

    team_results = Vector{Dict{String, Any}}(undef, n_teams)

    # First compute baseline (Pre-AI) metrics for each department
    base_team_cycle = zeros(Float64, n_teams)
    base_team_draft_util = zeros(Float64, n_teams)
    base_team_qa_util = zeros(Float64, n_teams)
    base_team_wait_qa = zeros(Float64, n_teams)

    for i in 1:n_teams
        tm = config.teams[i]
        wf = DEFAULT_DES_WORKFLOWS[i]
        n_items = round(Int, tm.headcount * wf.monthly_arrivals_per_fte)
        arr_rate = n_items / 160.0

        n_qa_servers = max(2, round(Int, tm.headcount * wf.qa_specialist_share))
        n_draft_servers = max(2, tm.headcount - n_qa_servers)

        w_d, s_d, _, u_d = simulate_stage_queue(rng, n_items, n_draft_servers, wf.baseline_draft_hours, arr_rate)
        w_q, s_q, _, u_q = simulate_stage_queue(rng, n_items, n_qa_servers, wf.baseline_qa_hours, arr_rate)

        base_team_cycle[i] = w_d + s_d + w_q + s_q
        base_team_draft_util[i] = u_d
        base_team_qa_util[i] = u_q
        base_team_wait_qa[i] = w_q
    end

    upfront_platform = 0.5 * (config.costs.upfront_platform_p10_usd + config.costs.upfront_platform_p90_usd)
    training_per_seat = config.costs.training_per_seat_mode_usd
    token_drift_annual = config.costs.token_drift_annual_mode
    monthly_token_drift = (1.0 + token_drift_annual)^(1.0 / 12.0) - 1.0
    monthly_discount_rate = (1.0 + config.costs.annual_discount_rate)^(1.0 / 12.0) - 1.0

    cum_cf = 0.0
    npv_acc = 0.0
    tot_cost = 0.0
    tot_net_ben = 0.0
    total_hours_saved_36m = 0.0

    # Store Month-36 team queue diagnostics
    m36_team_cycle = zeros(Float64, n_teams)
    m36_team_draft_util = zeros(Float64, n_teams)
    m36_team_qa_util = zeros(Float64, n_teams)
    m36_team_wait_qa = zeros(Float64, n_teams)
    m36_team_sla_pct = zeros(Float64, n_teams)
    m36_team_hours_saved_mo = zeros(Float64, n_teams)

    for m in 1:horizon_months
        adopt_m = logistic_adoption(m, ceiling, t0, k_steep)
        platform_m = m <= 4 ? 0.25 * upfront_platform : (upfront_platform * config.costs.ongoing_platform_maint_rate) / 12.0
        training_m = m <= 9 ? (training_per_seat * total_hc) / 9.0 : (training_per_seat * total_hc * 0.15) / 12.0
        token_factor = (1.0 + monthly_token_drift)^(m - 1)

        m_cost = platform_m + training_m
        m_ben = 0.0
        w_cycle = 0.0
        w_base_cycle = 0.0
        w_d_wait = 0.0
        w_q_wait = 0.0
        tot_items_m = 0.0
        hrs_saved_m = 0.0

        for i in 1:n_teams
            tm = config.teams[i]
            wf = DEFAULT_DES_WORKFLOWS[i]
            g_uplift = tm.gross_uplift_mode * config.uplift_multiplier
            r_drag = tm.rework_drag_mode * config.rework_multiplier
            real_f = clamp(tm.realization_factor_mode * config.realization_multiplier, 0.1, 0.98)

            # Volume grows slightly when teams try to push more items through AI
            volume_expansion = config.id == "blitzscale_mandate" ? (1.0 + 0.18 * adopt_m) : (1.0 + 0.08 * adopt_m)
            n_items = round(Int, tm.headcount * wf.monthly_arrivals_per_fte * volume_expansion)
            arr_rate = n_items / 160.0

            # Stage 1: AI Triage & Deflection reduces drafting service time
            speedup_factor = clamp(1.0 - adopt_m * tm.ai_addressable_task_share * g_uplift * 1.35 * ai_triage_deflection_boost, 0.42, 1.0)
            eff_draft_hrs = wf.baseline_draft_hours * speedup_factor

            # Stage 3: Verification & Rework inflation on QA stage when AI generates subtle errors
            rework_qa_inflation = 1.0 + adopt_m * (r_drag * 3.2 - 0.15 * g_uplift)
            eff_qa_hrs = wf.baseline_qa_hours * max(0.75, rework_qa_inflation)

            # Server allocation between Stage 2 (Drafting) and Stage 3 (QA Review)
            qa_share_eff = clamp(wf.qa_specialist_share + adopt_m * scenario_qa_shift, 0.15, 0.48)
            n_qa_servers = max(2, round(Int, tm.headcount * qa_share_eff))
            n_draft_servers = max(2, tm.headcount - n_qa_servers)

            w_d, s_d, p90_wd, u_d = simulate_stage_queue(rng, n_items, n_draft_servers, eff_draft_hrs, arr_rate)
            w_q, s_q, p90_wq, u_q = simulate_stage_queue(rng, n_items, n_qa_servers, eff_qa_hrs, arr_rate)

            cyc_m = w_d + s_d + w_q + s_q

            # Direct work hours saved vs baseline per item
            baseline_work_hrs_per_item = wf.baseline_draft_hours + wf.baseline_qa_hours
            queue_congestion_penalty = min(0.25 * wf.baseline_qa_hours, 0.015 * max(0.0, w_q - base_team_wait_qa[i]))
            new_work_hrs_per_item = s_d + s_q + queue_congestion_penalty
            base_items = tm.headcount * wf.monthly_arrivals_per_fte
            team_hrs_saved = max(5.0, base_items * (baseline_work_hrs_per_item - new_work_hrs_per_item))

            hourly_rate = tm.fully_loaded_annual_cost_usd / (12.0 * 160.0)
            team_val_m = team_hrs_saved * hourly_rate * real_f
            team_seat_cost_m = tm.headcount * min(1.0, adopt_m * 1.15) * tm.seat_cost_monthly_mode * config.seat_cost_multiplier * token_factor

            m_ben += team_val_m
            m_cost += team_seat_cost_m
            hrs_saved_m += team_hrs_saved
            tot_items_m += n_items

            w_hc = tm.headcount / total_hc
            w_cycle += w_hc * cyc_m
            w_base_cycle += w_hc * base_team_cycle[i]
            w_d_wait += w_hc * w_d
            w_q_wait += w_hc * w_q

            if m == horizon_months
                m36_team_cycle[i] = cyc_m
                m36_team_draft_util[i] = u_d
                m36_team_qa_util[i] = u_q
                m36_team_wait_qa[i] = w_q
                m36_team_hours_saved_mo[i] = team_hrs_saved
                # Approximate SLA compliance from cycle time vs SLA target
                ratio_sla = cyc_m / wf.sla_target_hours
                m36_team_sla_pct[i] = round(clamp(100.0 * exp(-0.35 * max(0.0, ratio_sla - 0.55)), 40.0, 99.5), digits=1)
            end
        end

        net_cf_m = m_ben - m_cost
        cum_cf += net_cf_m
        npv_acc += net_cf_m / ((1.0 + monthly_discount_rate)^m)
        tot_cost += m_cost
        tot_net_ben += m_ben
        total_hours_saved_36m += hrs_saved_m

        monthly_cycle_time_hrs[m] = round(w_cycle, digits=2)
        monthly_baseline_cycle_hrs[m] = round(w_base_cycle, digits=2)
        monthly_draft_wait_hrs[m] = round(w_d_wait, digits=2)
        monthly_qa_wait_hrs[m] = round(w_q_wait, digits=2)
        monthly_throughput_items[m] = round(tot_items_m, digits=0)
        monthly_hours_saved[m] = round(hrs_saved_m, digits=0)
        monthly_cum_cashflow[m] = round(cum_cf, digits=0)
    end

    for i in 1:n_teams
        tm = config.teams[i]
        wf = DEFAULT_DES_WORKFLOWS[i]
        bottleneck_status = if m36_team_qa_util[i] >= 85.0
            "Backed Up at Final Human Review (>85% Busy)"
        elseif m36_team_qa_util[i] >= 75.0
            "Moderate Line at Final Review"
        else
            "Smooth Flow (Short Wait Lines)"
        end

        team_results[i] = Dict{String, Any}(
            "team_id" => tm.id,
            "team_name" => tm.name,
            "work_unit_name" => wf.work_unit_name,
            "baseline_cycle_time_hrs" => round(base_team_cycle[i], digits=1),
            "m36_cycle_time_hrs" => round(m36_team_cycle[i], digits=1),
            "cycle_time_reduction_pct" => round(((base_team_cycle[i] - m36_team_cycle[i]) / base_team_cycle[i]) * 100.0, digits=1),
            "baseline_draft_utilization_pct" => round(base_team_draft_util[i], digits=1),
            "m36_draft_utilization_pct" => round(m36_team_draft_util[i], digits=1),
            "baseline_qa_utilization_pct" => round(base_team_qa_util[i], digits=1),
            "m36_qa_utilization_pct" => round(m36_team_qa_util[i], digits=1),
            "baseline_qa_wait_hrs" => round(base_team_wait_qa[i], digits=2),
            "m36_qa_wait_hrs" => round(m36_team_wait_qa[i], digits=2),
            "m36_hours_saved_monthly" => round(m36_team_hours_saved_mo[i], digits=0),
            "m36_sla_compliance_pct" => m36_team_sla_pct[i],
            "bottleneck_diagnosis" => bottleneck_status
        )
    end

    roi_pct = ((tot_net_ben - tot_cost) / max(1.0, tot_cost)) * 100.0
    cycle_reduction_overall = ((monthly_baseline_cycle_hrs[end] - monthly_cycle_time_hrs[end]) / monthly_baseline_cycle_hrs[end]) * 100.0

    return Dict{String, Any}(
        "paradigm" => "discrete_event",
        "scenario_id" => config.id,
        "scenario_name" => config.name,
        "parameters" => Dict{String, Any}(
            "horizon_months" => horizon_months,
            "ai_triage_deflection_boost" => round(ai_triage_deflection_boost, digits=2),
            "qa_capacity_reallocation_pct" => round(scenario_qa_shift * 100.0, digits=1)
        ),
        "kpis" => Dict{String, Any}(
            "process_roi_pct" => round(roi_pct, digits=1),
            "process_npv_usd" => round(npv_acc, digits=0),
            "total_hours_saved_36m" => round(total_hours_saved_36m, digits=0),
            "baseline_avg_cycle_time_hrs" => monthly_baseline_cycle_hrs[end],
            "m36_avg_cycle_time_hrs" => monthly_cycle_time_hrs[end],
            "cycle_time_reduction_pct" => round(cycle_reduction_overall, digits=1),
            "m36_qa_queue_wait_hrs" => monthly_qa_wait_hrs[end]
        ),
        "trajectories" => Dict{String, Any}(
            "months" => collect(1:horizon_months),
            "baseline_cycle_time_hrs" => monthly_baseline_cycle_hrs,
            "ai_cycle_time_hrs" => monthly_cycle_time_hrs,
            "draft_stage_wait_hrs" => monthly_draft_wait_hrs,
            "qa_review_stage_wait_hrs" => monthly_qa_wait_hrs,
            "monthly_throughput_items" => monthly_throughput_items,
            "monthly_hours_saved" => monthly_hours_saved,
            "cumulative_cashflow_usd" => monthly_cum_cashflow
        ),
        "workflows" => team_results
    )
end
