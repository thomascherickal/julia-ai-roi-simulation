# Paradigm 3: System Dynamics (SD)
# Macro-level feedback loops (Reinforcing & Balancing), stocks, and flows solved via 4th-order Runge-Kutta (RK4).
# Models compounding AI workflow mastery & proprietary data moat vs. technical debt/verification drag & token cost sprawl.

"""
    run_system_dynamics_model(config::ScenarioConfig; horizon_months::Int=36, dt::Float64=0.25,
                              reinvestment_rate::Float64=-1.0, governance_damping::Float64=-1.0,
                              automation_ambition::Float64=-1.0)

Solves the coupled nonlinear ODE system of 4 macro organizational stocks over `horizon_months` using RK4:
- Stock 1: `A(t)` Adopted Workforce Fraction (0..1)
- Stock 2: `M(t)` Organizational AI Workflow Mastery & Proprietary Data Moat (0..1.5)
- Stock 3: `D(t)` AI Technical Debt & Unverified Rework Backlog (0..1)
- Stock 4: `S(t)` Autonomous Compute & Token Sprawl Multiplier (1.0..4.0)
"""
function run_system_dynamics_model(
    config::ScenarioConfig;
    horizon_months::Int=36,
    dt::Float64=0.25,
    reinvestment_rate::Float64=-1.0,
    governance_damping::Float64=-1.0,
    automation_ambition::Float64=-1.0
)
    total_hc = sum(t.headcount for t in config.teams)
    total_annual_payroll = sum(t.headcount * t.fully_loaded_annual_cost_usd for t in config.teams)
    monthly_payroll = total_annual_payroll / 12.0

    # Weighted baseline team attributes
    w_addressable = sum((t.headcount / total_hc) * t.ai_addressable_task_share for t in config.teams)
    w_gross = sum((t.headcount / total_hc) * t.gross_uplift_mode for t in config.teams) * config.uplift_multiplier
    w_rework = sum((t.headcount / total_hc) * t.rework_drag_mode for t in config.teams) * config.rework_multiplier
    w_seat_cost = sum((t.headcount / total_hc) * t.seat_cost_monthly_mode for t in config.teams) * config.seat_cost_multiplier
    w_real = clamp(sum((t.headcount / total_hc) * t.realization_factor_mode for t in config.teams) * config.realization_multiplier, 0.1, 0.98)

    # Scenario macro feedback parameters
    reinvest = if reinvestment_rate >= 0.0
        reinvestment_rate
    elseif config.id == "agentic_transformation"
        0.38
    elseif config.id == "pragmatic_phased"
        0.26
    elseif config.id == "conservative_pilot"
        0.22
    else
        0.12 # Blitzscale under-invests in workflow architecture
    end

    gov_damp = if governance_damping >= 0.0
        governance_damping
    elseif config.id == "conservative_pilot"
        0.42
    elseif config.id == "pragmatic_phased"
        0.32
    elseif config.id == "agentic_transformation"
        0.35
    else
        0.12 # Blitzscale has weak governance damping on tech debt & token sprawl
    end

    ambition = if automation_ambition >= 0.0
        automation_ambition
    elseif config.id == "blitzscale_mandate"
        0.65
    elseif config.id == "agentic_transformation"
        0.55
    elseif config.id == "pragmatic_phased"
        0.40
    else
        0.24
    end

    ceiling = config.rollout.ceiling_mode
    upfront_platform = 0.5 * (config.costs.upfront_platform_p10_usd + config.costs.upfront_platform_p90_usd)
    training_per_seat = config.costs.training_per_seat_mode_usd

    # Coupled ODE derivative function: dY/dt = f(t, Y)
    # Y = [A, M, D, S]
    function derivatives(y::Vector{Float64})
        A = clamp(y[1], 0.01, 0.99)
        M = clamp(y[2], 0.0, 1.50)
        D = clamp(y[3], 0.0, 1.00)
        S = clamp(y[4], 1.0, 5.00)

        # Reinforcing Loop R1: Word-of-mouth + management ambition + mastery acceleration
        inflow_adoption = (0.045 * ambition + 0.32 * A * (1.0 + 0.45 * M)) * max(0.0, ceiling - A)
        # Balancing Loop B1: Tech-debt & hallucination fatigue causing abandonment
        outflow_churn = 0.16 * D * A * (1.0 - 0.5 * gov_damp)
        dA = inflow_adoption - outflow_churn

        # Reinforcing Loop R2: Learning-by-doing & reinvestment build Workflow Mastery & Data Moat
        inflow_mastery = (0.055 * reinvest * A + 0.025 * A * (1.0 - D)) * max(0.0, 1.25 - M)
        outflow_obsolescence = 0.018 * M
        dM = inflow_mastery - outflow_obsolescence

        # Balancing Loop B2: Unverified AI volume builds Tech Debt / Verification Backlog; Governance drains it
        inflow_debt = 0.085 * ambition * A * (w_rework / 0.06) * max(0.2, 1.0 - 0.65 * M)
        outflow_remediation = (0.14 + 0.38 * gov_damp + 0.12 * M) * D
        dD = inflow_debt - outflow_remediation

        # Balancing Loop B3: Multi-agent loops & context expansion drive Token Sprawl; FinOps governance caps it
        inflow_sprawl = 0.048 * ambition * A * S * (1.0 - 0.55 * gov_damp)
        outflow_finops = 0.065 * gov_damp * (S - 1.0)
        dS = inflow_sprawl - outflow_finops

        return [dA, dM, dD, dS]
    end

    # Initial Stock State at Month 0
    y = [
        config.id == "blitzscale_mandate" ? 0.18 : 0.06, # Initial A(0)
        0.10,                                            # Initial Mastery M(0)
        0.02,                                            # Initial Tech Debt D(0)
        1.00                                             # Initial Token Sprawl S(0)
    ]

    steps_per_month = max(1, round(Int, 1.0 / dt))
    eff_dt = 1.0 / steps_per_month

    stock_A = Vector{Float64}(undef, horizon_months)
    stock_M = Vector{Float64}(undef, horizon_months)
    stock_D = Vector{Float64}(undef, horizon_months)
    stock_S = Vector{Float64}(undef, horizon_months)

    flow_gross_benefit = Vector{Float64}(undef, horizon_months)
    flow_debt_drag = Vector{Float64}(undef, horizon_months)
    flow_compute_cost = Vector{Float64}(undef, horizon_months)
    flow_net_cashflow = Vector{Float64}(undef, horizon_months)
    flow_cum_cashflow = Vector{Float64}(undef, horizon_months)
    loop_dominance_score = Vector{Float64}(undef, horizon_months) # >0 Reinforcing dominates, <0 Balancing dominates

    cum_cf = 0.0
    npv_acc = 0.0
    tot_cost = 0.0
    tot_net_ben = 0.0
    tot_gross_ben = 0.0
    tot_debt_drag = 0.0
    monthly_discount_rate = (1.0 + config.costs.annual_discount_rate)^(1.0 / 12.0) - 1.0

    for m in 1:horizon_months
        # Integrate 1 month via RK4
        for _ in 1:steps_per_month
            k1 = derivatives(y)
            k2 = derivatives(y .+ 0.5 .* eff_dt .* k1)
            k3 = derivatives(y .+ 0.5 .* eff_dt .* k2)
            k4 = derivatives(y .+ eff_dt .* k3)
            y = y .+ (eff_dt / 6.0) .* (k1 .+ 2.0 .* k2 .+ 2.0 .* k3 .+ k4)
            y[1] = clamp(y[1], 0.01, 0.99)
            y[2] = clamp(y[2], 0.0, 1.50)
            y[3] = clamp(y[3], 0.0, 1.00)
            y[4] = clamp(y[4], 1.0, 5.00)
        end

        A_m, M_m, D_m, S_m = y[1], y[2], y[3], y[4]
        stock_A[m] = round(A_m * 100.0, digits=1)
        stock_M[m] = round(M_m * 100.0, digits=1)
        stock_D[m] = round(D_m * 100.0, digits=1)
        stock_S[m] = round(S_m, digits=2)

        # Compounding productivity gain from Mastery (R2) vs. Tech Debt drag (B2)
        mastery_multiplier = 0.70 + 0.65 * M_m
        gross_val_m = monthly_payroll * A_m * w_addressable * w_gross * mastery_multiplier * w_real
        debt_drag_m = monthly_payroll * A_m * (w_addressable * w_rework + 0.14 * D_m) * w_real
        net_ben_m = gross_val_m - debt_drag_m

        platform_m = m <= 4 ? 0.25 * upfront_platform : (upfront_platform * config.costs.ongoing_platform_maint_rate) / 12.0
        training_m = m <= 9 ? (training_per_seat * total_hc) / 9.0 : (training_per_seat * total_hc * reinvest * 0.5) / 12.0
        provisioned_seats = total_hc * min(1.0, A_m * 1.15)
        seat_compute_m = provisioned_seats * w_seat_cost * S_m
        cost_m = platform_m + training_m + seat_compute_m

        net_cf_m = net_ben_m - cost_m
        cum_cf += net_cf_m
        npv_acc += net_cf_m / ((1.0 + monthly_discount_rate)^m)
        tot_cost += cost_m
        tot_net_ben += net_ben_m
        tot_gross_ben += gross_val_m
        tot_debt_drag += debt_drag_m

        flow_gross_benefit[m] = round(gross_val_m, digits=0)
        flow_debt_drag[m] = round(debt_drag_m, digits=0)
        flow_compute_cost[m] = round(cost_m, digits=0)
        flow_net_cashflow[m] = round(net_cf_m, digits=0)
        flow_cum_cashflow[m] = round(cum_cf, digits=0)

        # Net reinforcing force vs balancing drag index
        r_force = A_m * mastery_multiplier * 100.0
        b_force = (D_m * 140.0) + (S_m - 1.0) * 35.0
        loop_dominance_score[m] = round(r_force - b_force, digits=1)
    end

    roi_pct = ((tot_net_ben - tot_cost) / max(1.0, tot_cost)) * 100.0

    causal_loops = [
        Dict{String, Any}(
            "id" => "Flywheel 1",
            "type" => "Growth Flywheel (+)",
            "name" => "Word-of-Mouth & Shared Tips",
            "pathway" => "More Active Users → Better Shared Templates → Easier for Coworkers → Faster Adoption",
            "impact_summary" => "Speeds up team-wide adoption once roughly 1 in 4 employees are using the tool daily."
        ),
        Dict{String, Any}(
            "id" => "Flywheel 2",
            "type" => "Growth Flywheel (+)",
            "name" => "Growing Company Know-How",
            "pathway" => "Daily Practice + Training → Stronger Company Playbooks → Bigger Time Savings & Fewer Mistakes",
            "impact_summary" => "Boosts output per person by $(round(0.70 + 0.65 * (stock_M[end]/100.0), digits=2))x by Month 36."
        ),
        Dict{String, Any}(
            "id" => "Brake 1",
            "type" => "Hidden Brake (-)",
            "name" => "Sloppy AI Cleanup Backlog",
            "pathway" => "Rushed AI Output → Pileup of Unchecked Work → Extra Time Fixing Mistakes → Staff Burnout",
            "impact_summary" => "Costs \$$(round(Int, tot_debt_drag / 1000))k in extra cleanup and rework over 36 months."
        ),
        Dict{String, Any}(
            "id" => "Brake 2",
            "type" => "Hidden Brake (-)",
            "name" => "Climbing Monthly AI Usage Bills",
            "pathway" => "Automated Multi-Step Tasks → Higher Cloud Usage per Person → Rising Monthly Bills → Lower Profit",
            "impact_summary" => "Pushes monthly usage bills to $(stock_S[end])x per seat by Month 36 without budget guardrails."
        )
    ]

    return Dict{String, Any}(
        "paradigm" => "system_dynamics",
        "scenario_id" => config.id,
        "scenario_name" => config.name,
        "parameters" => Dict{String, Any}(
            "horizon_months" => horizon_months,
            "rk4_step_months" => eff_dt,
            "reinvestment_rate" => round(reinvest, digits=2),
            "governance_damping" => round(gov_damp, digits=2),
            "automation_ambition" => round(ambition, digits=2)
        ),
        "kpis" => Dict{String, Any}(
            "equilibrium_roi_pct" => round(roi_pct, digits=1),
            "equilibrium_npv_usd" => round(npv_acc, digits=0),
            "total_gross_value_36m_usd" => round(tot_gross_ben, digits=0),
            "total_tech_debt_drag_36m_usd" => round(tot_debt_drag, digits=0),
            "total_cost_36m_usd" => round(tot_cost, digits=0),
            "m36_adopted_workforce_pct" => stock_A[end],
            "m36_workflow_mastery_index" => stock_M[end],
            "m36_tech_debt_index" => stock_D[end],
            "m36_token_sprawl_multiplier" => stock_S[end]
        ),
        "stocks_and_flows" => Dict{String, Any}(
            "months" => collect(1:horizon_months),
            "stock_adopted_workforce_pct" => stock_A,
            "stock_workflow_mastery_index" => stock_M,
            "stock_tech_debt_index" => stock_D,
            "stock_token_sprawl_multiplier" => stock_S,
            "flow_gross_benefit_usd" => flow_gross_benefit,
            "flow_debt_drag_usd" => flow_debt_drag,
            "flow_total_cost_usd" => flow_compute_cost,
            "flow_net_cashflow_usd" => flow_net_cashflow,
            "flow_cumulative_cashflow_usd" => flow_cum_cashflow,
            "loop_dominance_score" => loop_dominance_score
        ),
        "causal_loops" => causal_loops
    )
end

