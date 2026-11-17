# Paradigm 2: Agent-Based Modeling (ABM)
# Bottom-up interaction of 325 individual employees across a workplace peer network.
# Captures employee adoption friction, peer word-of-mouth contagion, hallucination frustration, and champion seeding.

# Agent States:
# 1 = Skeptical (Non-adopter)
# 2 = Exploring (Onboarding / J-curve learning friction)
# 3 = Proficient (Habitual copilot user generating net value)
# 4 = Champion (High-skill mentor accelerating peers' transition)
# 5 = Disillusioned (Churned due to unmitigated AI hallucinations / verification fatigue)

"""
    run_agent_based_model(config::ScenarioConfig; n_replications::Int=200, horizon_months::Int=36, seed::Int=20261117,
                          champion_seed_fraction::Float64=-1.0, peer_contagion_strength::Float64=-1.0,
                          frustration_sensitivity::Float64=-1.0)

Simulates 325 individual employee agents arranged in a small-world departmental + cross-functional network.
Returns full state trajectories (Skeptical, Exploring, Proficient, Champion, Disillusioned),
departmental adoption breakdown, and P10/P50/P90 emergent financial ROI.
"""
function run_agent_based_model(
    config::ScenarioConfig;
    n_replications::Int=200,
    horizon_months::Int=36,
    seed::Int=20261117,
    champion_seed_fraction::Float64=-1.0,
    peer_contagion_strength::Float64=-1.0,
    frustration_sensitivity::Float64=-1.0
)
    rng = MersenneTwister(seed)
    n_teams = length(config.teams)
    total_agents = sum(t.headcount for t in config.teams)

    # Derive scenario-specific behavioral defaults if not overridden
    base_seed_frac = if champion_seed_fraction >= 0.0
        champion_seed_fraction
    elseif config.id == "agentic_transformation"
        0.09
    elseif config.id == "pragmatic_phased"
        0.06
    elseif config.id == "blitzscale_mandate"
        0.03
    else
        0.04
    end

    base_contagion = if peer_contagion_strength >= 0.0
        peer_contagion_strength
    elseif config.id == "blitzscale_mandate"
        0.48
    elseif config.id == "agentic_transformation"
        0.44
    elseif config.id == "pragmatic_phased"
        0.38
    else
        0.26
    end

    base_frustration = if frustration_sensitivity >= 0.0
        frustration_sensitivity
    elseif config.id == "blitzscale_mandate"
        0.11
    elseif config.id == "conservative_pilot"
        0.03
    elseif config.id == "pragmatic_phased"
        0.04
    else
        0.035
    end

    # Map each agent (1..325) to its department index (1..4)
    agent_team = Vector{Int}(undef, total_agents)
    idx_cursor = 1
    for (t_idx, tm) in enumerate(config.teams)
        for _ in 1:tm.headcount
            agent_team[idx_cursor] = t_idx
            idx_cursor += 1
        end
    end

    # Pre-allocate replication outputs
    rep_roi_pct = Vector{Float64}(undef, n_replications)
    rep_npv_usd = Vector{Float64}(undef, n_replications)
    rep_active_pct_m36 = Vector{Float64}(undef, n_replications)
    rep_churned_pct_m36 = Vector{Float64}(undef, n_replications)

    # State trajectories across replications: (n_replications, horizon_months)
    traj_skeptical = Matrix{Float64}(undef, n_replications, horizon_months)
    traj_exploring = Matrix{Float64}(undef, n_replications, horizon_months)
    traj_proficient = Matrix{Float64}(undef, n_replications, horizon_months)
    traj_champion = Matrix{Float64}(undef, n_replications, horizon_months)
    traj_disillusioned = Matrix{Float64}(undef, n_replications, horizon_months)
    traj_active_adoption = Matrix{Float64}(undef, n_replications, horizon_months)
    traj_cum_cashflow = Matrix{Float64}(undef, n_replications, horizon_months)
    traj_net_uplift = Matrix{Float64}(undef, n_replications, horizon_months)

    team_m36_active = Matrix{Float64}(undef, n_replications, n_teams)
    team_m36_champion = Matrix{Float64}(undef, n_replications, n_teams)
    team_m36_churned = Matrix{Float64}(undef, n_replications, n_teams)
    team_roi_pct = Matrix{Float64}(undef, n_replications, n_teams)

    monthly_discount_rate = (1.0 + config.costs.annual_discount_rate)^(1.0 / 12.0) - 1.0

    # Sample network snapshot for visual graph rendering (saved from replication 1)
    sample_nodes = Vector{Dict{String, Any}}()
    sample_edges = Vector{Dict{String, Any}}()

    for rep in 1:n_replications
        # Build small-world workplace interaction network (6 peers per employee: 4 intra-team, 2 cross-team)
        neighbors = [Int[] for _ in 1:total_agents]
        for a in 1:total_agents
            t_a = agent_team[a]
            # Connect to 4 local colleagues within the same team ring + random shortcut
            for offset in (1, 2, 5)
                candidate = mod1(a + offset, total_agents)
                if candidate != a && !(candidate in neighbors[a])
                    push!(neighbors[a], candidate)
                    push!(neighbors[candidate], a)
                end
            end
            # Random cross-functional link
            cross = rand(rng, 1:total_agents)
            if cross != a && !(cross in neighbors[a])
                push!(neighbors[a], cross)
                push!(neighbors[cross], a)
            end
        end

        # Initialize agent states & individual traits
        state = fill(1, total_agents) # 1 = Skeptical
        skill = zeros(Float64, total_agents)
        openness = [clamp(0.50 + 0.22 * randn(rng), 0.05, 0.98) for _ in 1:total_agents]

        # Seed initial AI champions and early explorers
        for a in 1:total_agents
            r_draw = rand(rng)
            if r_draw < base_seed_frac
                state[a] = 4 # Champion
                skill[a] = 0.85
            elseif r_draw < base_seed_frac * 2.2
                state[a] = 2 # Exploring
                skill[a] = 0.25
            end
        end

        upfront_platform = sample_lognormal_from_ci(rng, config.costs.upfront_platform_p10_usd, config.costs.upfront_platform_p90_usd)
        training_per_seat = sample_triangular(rng, config.costs.training_per_seat_min_usd, config.costs.training_per_seat_mode_usd, config.costs.training_per_seat_max_usd)
        token_drift_annual = sample_triangular(rng, config.costs.token_drift_annual_min, config.costs.token_drift_annual_mode, config.costs.token_drift_annual_max)
        monthly_token_drift = (1.0 + token_drift_annual)^(1.0 / 12.0) - 1.0

        # Sample team parameters
        t_gross = [sample_triangular(rng, tm.gross_uplift_min, tm.gross_uplift_mode, tm.gross_uplift_max) * config.uplift_multiplier for tm in config.teams]
        t_rework = [sample_triangular(rng, tm.rework_drag_min, tm.rework_drag_mode, tm.rework_drag_max) * config.rework_multiplier for tm in config.teams]
        t_seat = [sample_triangular(rng, tm.seat_cost_monthly_min, tm.seat_cost_monthly_mode, tm.seat_cost_monthly_max) * config.seat_cost_multiplier for tm in config.teams]
        t_real = [clamp(sample_triangular(rng, tm.realization_factor_min, tm.realization_factor_mode, tm.realization_factor_max) * config.realization_multiplier, 0.1, 0.98) for tm in config.teams]

        # Training enablement boost from organizational investment
        enablement_quality = clamp(training_per_seat / 900.0, 0.25, 1.6)
        mandate_push = config.id == "blitzscale_mandate" ? 0.14 : (config.id == "conservative_pilot" ? 0.02 : 0.05)

        cum_cf = 0.0
        npv_acc = 0.0
        tot_cost = 0.0
        tot_net_ben = 0.0
        team_cost_acc = zeros(Float64, n_teams)
        team_ben_acc = zeros(Float64, n_teams)

        next_state = similar(state)

        for m in 1:horizon_months
            copyto!(next_state, state)

            # Bottom-up agent state transitions
            for a in 1:total_agents
                nb = neighbors[a]
                n_nb = max(1, length(nb))
                active_peers = count(j -> state[j] == 3 || state[j] == 4, nb)
                champ_peers = count(j -> state[j] == 4, nb)
                churn_peers = count(j -> state[j] == 5, nb)

                peer_positive_ratio = (active_peers + 1.8 * champ_peers) / n_nb
                peer_negative_ratio = churn_peers / n_nb

                st = state[a]
                if st == 1 # Skeptical -> Exploring
                    # Contagion from peers + management push, dampened by disillusioned peers
                    p_try = clamp(
                        openness[a] * (base_contagion * peer_positive_ratio + mandate_push) * (1.0 - 0.5 * peer_negative_ratio),
                        0.0, 0.85
                    )
                    if rand(rng) < p_try
                        next_state[a] = 2
                        skill[a] = 0.15
                    end
                elseif st == 2 # Exploring -> Proficient or Disillusioned
                    # Mentorship from Champions and training accelerates learning
                    learn_step = 0.18 * enablement_quality + 0.14 * (champ_peers / n_nb) + 0.06 * openness[a]
                    skill[a] = min(1.0, skill[a] + learn_step)

                    # Frustration risk if rework is high and enablement is low
                    t_idx = agent_team[a]
                    rework_stress = base_frustration * (t_rework[t_idx] / 0.07) / enablement_quality
                    if rand(rng) < clamp(rework_stress, 0.01, 0.45)
                        next_state[a] = 5 # Disillusioned
                    elseif skill[a] >= 0.52
                        next_state[a] = 3 # Proficient
                    end
                elseif st == 3 # Proficient -> Champion or Disillusioned relapse
                    skill[a] = min(1.0, skill[a] + 0.05 * enablement_quality)
                    p_promote = 0.04 * enablement_quality * openness[a]
                    p_relapse = 0.015 * base_frustration * (1.0 + peer_negative_ratio)
                    u = rand(rng)
                    if u < p_promote && skill[a] > 0.78
                        next_state[a] = 4 # Champion
                    elseif u < p_promote + p_relapse
                        next_state[a] = 5 # Disillusioned
                    end
                elseif st == 5 # Disillusioned -> Re-onboarding if surrounded by Champions
                    p_recover = clamp(0.12 * enablement_quality * (champ_peers / n_nb), 0.005, 0.35)
                    if rand(rng) < p_recover
                        next_state[a] = 2
                        skill[a] = 0.30
                    end
                end
            end

            copyto!(state, next_state)

            # Aggregate monthly counts & emergent bottom-up financials
            c_skep = count(==(1), state)
            c_expl = count(==(2), state)
            c_prof = count(==(3), state)
            c_champ = count(==(4), state)
            c_dis = count(==(5), state)

            traj_skeptical[rep, m] = (c_skep / total_agents) * 100.0
            traj_exploring[rep, m] = (c_expl / total_agents) * 100.0
            traj_proficient[rep, m] = (c_prof / total_agents) * 100.0
            traj_champion[rep, m] = (c_champ / total_agents) * 100.0
            traj_disillusioned[rep, m] = (c_dis / total_agents) * 100.0
            traj_active_adoption[rep, m] = ((c_prof + c_champ) / total_agents) * 100.0

            platform_m = m <= 4 ? 0.25 * upfront_platform : (upfront_platform * config.costs.ongoing_platform_maint_rate) / 12.0
            training_m = m <= 9 ? (training_per_seat * total_agents) / 9.0 : (training_per_seat * total_agents * 0.15) / 12.0
            shared_overhead_m = platform_m + training_m
            token_factor = (1.0 + monthly_token_drift)^(m - 1)

            m_cost = shared_overhead_m
            m_net_ben = 0.0
            weighted_uplift_m = 0.0

            for a in 1:total_agents
                t_idx = agent_team[a]
                tm = config.teams[t_idx]
                monthly_sal = tm.fully_loaded_annual_cost_usd / 12.0
                st = state[a]

                # Individual agent productivity & license consumption
                if st == 2 # Exploring (J-curve learning friction + seat cost)
                    agent_net_gain = tm.ai_addressable_task_share * (0.25 * t_gross[t_idx] - 1.35 * t_rework[t_idx]) - 0.03
                    m_net_ben += monthly_sal * agent_net_gain * t_real[t_idx]
                    c_seat = t_seat[t_idx] * token_factor
                    m_cost += c_seat
                    team_cost_acc[t_idx] += c_seat
                    team_ben_acc[t_idx] += monthly_sal * agent_net_gain * t_real[t_idx]
                    weighted_uplift_m += agent_net_gain / total_agents
                elseif st == 3 # Proficient
                    eff_rework = t_rework[t_idx] * (1.15 - 0.45 * skill[a])
                    agent_net_gain = tm.ai_addressable_task_share * (t_gross[t_idx] * (0.75 + 0.35 * skill[a]) - eff_rework)
                    val_a = monthly_sal * agent_net_gain * t_real[t_idx]
                    c_seat = t_seat[t_idx] * token_factor
                    m_net_ben += val_a
                    m_cost += c_seat
                    team_cost_acc[t_idx] += c_seat
                    team_ben_acc[t_idx] += val_a
                    weighted_uplift_m += agent_net_gain / total_agents
                elseif st == 4 # Champion (1.28x productivity + lower rework)
                    eff_rework = 0.45 * t_rework[t_idx]
                    agent_net_gain = tm.ai_addressable_task_share * (1.28 * t_gross[t_idx] - eff_rework)
                    val_a = monthly_sal * agent_net_gain * t_real[t_idx]
                    c_seat = 1.15 * t_seat[t_idx] * token_factor
                    m_net_ben += val_a
                    m_cost += c_seat
                    team_cost_acc[t_idx] += c_seat
                    team_ben_acc[t_idx] += val_a
                    weighted_uplift_m += agent_net_gain / total_agents
                elseif st == 5 # Disillusioned (shelfware license drag for 30% of churned seats)
                    c_seat = 0.30 * t_seat[t_idx] * token_factor
                    m_cost += c_seat
                    team_cost_acc[t_idx] += c_seat
                end
            end

            for i in 1:n_teams
                team_cost_acc[i] += shared_overhead_m * (config.teams[i].headcount / total_agents)
            end

            net_cf_m = m_net_ben - m_cost
            cum_cf += net_cf_m
            npv_acc += net_cf_m / ((1.0 + monthly_discount_rate)^m)
            tot_cost += m_cost
            tot_net_ben += m_net_ben

            traj_cum_cashflow[rep, m] = cum_cf
            traj_net_uplift[rep, m] = weighted_uplift_m * 100.0
        end

        rep_roi_pct[rep] = ((tot_net_ben - tot_cost) / max(1.0, tot_cost)) * 100.0
        rep_npv_usd[rep] = npv_acc
        rep_active_pct_m36[rep] = traj_active_adoption[rep, horizon_months]
        rep_churned_pct_m36[rep] = traj_disillusioned[rep, horizon_months]

        for i in 1:n_teams
            t_agents = findall(==(i), agent_team)
            n_ta = length(t_agents)
            team_m36_active[rep, i] = (count(a -> state[a] == 3 || state[a] == 4, t_agents) / n_ta) * 100.0
            team_m36_champion[rep, i] = (count(a -> state[a] == 4, t_agents) / n_ta) * 100.0
            team_m36_churned[rep, i] = (count(a -> state[a] == 5, t_agents) / n_ta) * 100.0
            team_roi_pct[rep, i] = ((team_ben_acc[i] - team_cost_acc[i]) / max(1.0, team_cost_acc[i])) * 100.0
        end

        # Save a representative 48-node network subsample on replication 1 for visual graph rendering
        if rep == 1
            stride = max(1, div(total_agents, 48))
            sampled_ids = collect(1:stride:total_agents)[1:min(48, end)]
            id_set = Set(sampled_ids)
            for (vis_idx, a) in enumerate(sampled_ids)
                push!(sample_nodes, Dict{String, Any}(
                    "id" => vis_idx,
                    "agent_id" => a,
                    "team_id" => config.teams[agent_team[a]].id,
                    "team_name" => config.teams[agent_team[a]].name,
                    "final_state" => state[a],
                    "skill" => round(skill[a], digits=2)
                ))
            end
            for (u_idx, a) in enumerate(sampled_ids)
                for b in neighbors[a]
                    v_idx = findfirst(==(b), sampled_ids)
                    if v_idx !== nothing && u_idx < v_idx
                        push!(sample_edges, Dict{String, Any}("source" => u_idx, "target" => v_idx))
                    end
                end
            end
        end
    end

    team_breakdown = [
        Dict{String, Any}(
            "id" => config.teams[i].id,
            "name" => config.teams[i].name,
            "headcount" => config.teams[i].headcount,
            "active_adopters_m36_pct" => quantile_summary(view(team_m36_active, :, i), digits=1),
            "champions_m36_pct" => quantile_summary(view(team_m36_champion, :, i), digits=1),
            "disillusioned_churn_m36_pct" => quantile_summary(view(team_m36_churned, :, i), digits=1),
            "emergent_roi_pct" => quantile_summary(view(team_roi_pct, :, i), digits=1)
        )
        for i in 1:n_teams
    ]

    return Dict{String, Any}(
        "paradigm" => "agent_based",
        "scenario_id" => config.id,
        "scenario_name" => config.name,
        "parameters" => Dict{String, Any}(
            "total_agents" => total_agents,
            "n_replications" => n_replications,
            "champion_seed_fraction_pct" => round(base_seed_frac * 100.0, digits=1),
            "peer_contagion_strength" => round(base_contagion, digits=2),
            "frustration_sensitivity" => round(base_frustration, digits=2)
        ),
        "kpis" => Dict{String, Any}(
            "emergent_roi_pct" => quantile_summary(rep_roi_pct, digits=1),
            "emergent_npv_usd" => quantile_summary(rep_npv_usd, digits=0),
            "m36_active_adopters_pct" => quantile_summary(rep_active_pct_m36, digits=1),
            "m36_disillusioned_churn_pct" => quantile_summary(rep_churned_pct_m36, digits=1)
        ),
        "state_trajectories" => Dict{String, Any}(
            "months" => collect(1:horizon_months),
            "skeptical_pct" => matrix_quantiles(traj_skeptical, digits=1),
            "exploring_pct" => matrix_quantiles(traj_exploring, digits=1),
            "proficient_pct" => matrix_quantiles(traj_proficient, digits=1),
            "champion_pct" => matrix_quantiles(traj_champion, digits=1),
            "disillusioned_pct" => matrix_quantiles(traj_disillusioned, digits=1),
            "active_adoption_pct" => matrix_quantiles(traj_active_adoption, digits=1),
            "cumulative_cashflow_usd" => matrix_quantiles(traj_cum_cashflow, digits=0),
            "net_productivity_uplift_pct" => matrix_quantiles(traj_net_uplift, digits=2)
        ),
        "teams" => team_breakdown,
        "network_snapshot" => Dict{String, Any}(
            "nodes" => sample_nodes,
            "edges" => sample_edges
        )
    )
end
