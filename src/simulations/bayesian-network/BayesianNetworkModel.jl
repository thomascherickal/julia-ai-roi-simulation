# Paradigm 5: Bayesian Networks (BN)
# Directed Acyclic Graph (DAG) of conditional probability tables updated via exact Bayes' rule inference.
# Dynamically adjusts 3-Year ROI forecasts and Stage-Gate funding recommendations when Month-6 pilot telemetry arrives.

"""
    compute_bayesian_posterior(prior_exec::Vector{Float64}, prior_gov::Vector{Float64},
                               obs_adoption::Int, obs_rework::Int, obs_token_control::Int)

Performs exact Bayesian belief propagation over the 8-node AI Adoption DAG:
- Root 1: `ExecSupport` ∈ {1=Weak, 2=Moderate, 3=Strong}
- Root 2: `GovernanceMaturity` ∈ {1=AdHoc, 2=Managed, 3=AutomatedGuardrails}
- Child 3: `PilotAdoptionSignal` ∈ {1=Low (<45%), 2=Target (45-75%), 3=High (>75%)} (given ExecSupport)
- Child 4: `ReworkRateSignal` ∈ {1=High (>10%), 2=Moderate (5-10%), 3=Low (<5%)} (given GovernanceMaturity)
- Child 5: `TokenCostDiscipline` ∈ {1=Overrun, 2=OnBudget, 3=Optimized} (given GovernanceMaturity)
- Latent 6: `SustainedRealization` ∈ {1=Low, 2=Medium, 3=High} (given ExecSupport, PilotAdoption, ReworkRate)
- Target 7: `ThreeYearROIRegime` ∈ {1=Loss (<0%), 2=Modest (0-80%), 3=Strong (80-160%), 4=Outsized (>160%)}
  (given SustainedRealization, ReworkRate, TokenCostDiscipline)

Evidence codes (`obs_*`): `0` = Unobserved (Prior), `1` = Unfavorable/Low, `2` = Base/Medium, `3` = Favorable/High.
"""
function compute_bayesian_posterior(
    prior_exec::Vector{Float64},
    prior_gov::Vector{Float64},
    obs_adoption::Int=0,
    obs_rework::Int=0,
    obs_token_control::Int=0
)
    # Conditional Probability Tables (CPTs)
    # P(PilotAdoption | ExecSupport) [3x3: rows=ExecSupport, cols=Adoption(Low, Target, High)]
    cpt_adopt_given_exec = [
        0.55 0.35 0.10;
        0.20 0.55 0.25;
        0.06 0.34 0.60
    ]

    # P(ReworkRateSignal | GovernanceMaturity) [3x3: rows=Gov, cols=Rework(HighRework=1, Mod=2, LowRework=3)]
    cpt_rework_given_gov = [
        0.58 0.32 0.10;
        0.18 0.54 0.28;
        0.05 0.27 0.68
    ]

    # P(TokenCostDiscipline | GovernanceMaturity) [3x3: rows=Gov, cols=Token(Overrun=1, OnBudget=2, Optimized=3)]
    cpt_token_given_gov = [
        0.60 0.30 0.10;
        0.20 0.56 0.24;
        0.06 0.32 0.62
    ]

    # Accumulate joint probabilities over all discrete states
    post_exec = zeros(Float64, 3)
    post_gov = zeros(Float64, 3)
    post_adopt = zeros(Float64, 3)
    post_rework = zeros(Float64, 3)
    post_token = zeros(Float64, 3)
    post_realization = zeros(Float64, 3)
    post_roi_regime = zeros(Float64, 4) # [Loss, Modest, Strong, Outsized]

    total_likelihood = 0.0

    for e in 1:3, g in 1:3, a in 1:3, r in 1:3, t in 1:3
        # Apply hard evidence filters if observed (1..3)
        if obs_adoption != 0 && a != obs_adoption
            continue
        end
        if obs_rework != 0 && r != obs_rework
            continue
        end
        if obs_token_control != 0 && t != obs_token_control
            continue
        end

        p_base = prior_exec[e] * prior_gov[g] *
                 cpt_adopt_given_exec[e, a] *
                 cpt_rework_given_gov[g, r] *
                 cpt_token_given_gov[g, t]

        # P(SustainedRealization | e, a, r)
        score_real = 0.35 * e + 0.40 * a + 0.25 * r # ranges from 1.0 to 3.0
        p_real = if score_real < 1.65
            (0.68, 0.26, 0.06)
        elseif score_real < 2.35
            (0.16, 0.62, 0.22)
        else
            (0.04, 0.26, 0.70)
        end

        for z in 1:3
            p_z = p_base * p_real[z]
            # P(ThreeYearROIRegime | z, r, t)
            score_roi = 0.48 * z + 0.28 * r + 0.24 * t # ranges from 1.0 to 3.0
            p_reg = if score_roi < 1.55
                (0.54, 0.34, 0.10, 0.02)
            elseif score_roi < 2.05
                (0.16, 0.50, 0.27, 0.07)
            elseif score_roi < 2.50
                (0.04, 0.22, 0.52, 0.22)
            else
                (0.01, 0.08, 0.36, 0.55)
            end

            for reg in 1:4
                prob_joint = p_z * p_reg[reg]
                total_likelihood += prob_joint
                post_exec[e] += prob_joint
                post_gov[g] += prob_joint
                post_adopt[a] += prob_joint
                post_rework[r] += prob_joint
                post_token[t] += prob_joint
                post_realization[z] += prob_joint
                post_roi_regime[reg] += prob_joint
            end
        end
    end

    norm = max(1e-12, total_likelihood)
    post_exec ./= norm
    post_gov ./= norm
    post_adopt ./= norm
    post_rework ./= norm
    post_token ./= norm
    post_realization ./= norm
    post_roi_regime ./= norm

    return Dict{String, Vector{Float64}}(
        "exec_support" => post_exec,
        "governance" => post_gov,
        "pilot_adoption" => post_adopt,
        "rework_signal" => post_rework,
        "token_discipline" => post_token,
        "sustained_realization" => post_realization,
        "roi_regime" => post_roi_regime
    )
end

"""
    summarize_posterior_metrics(config::ScenarioConfig, beliefs::Dict{String, Vector{Float64}})

Translates the discrete ROI regime posterior probabilities `[P(Loss), P(Modest), P(Strong), P(Outsized)]`
into expected ROI (%), expected NPV (\$), P(Positive NPV), and a concrete Stage-Gate funding decision.
"""
function summarize_posterior_metrics(config::ScenarioConfig, beliefs::Dict{String, Vector{Float64}})
    reg_probs = beliefs["roi_regime"]
    # Representative regime midpoints scaled by scenario characteristics
    scale_f = config.uplift_multiplier * config.realization_multiplier / max(0.7, config.seat_cost_multiplier * 0.85)
    regime_roi_centers = [-28.0, 42.0 * scale_f, 118.0 * scale_f, 215.0 * scale_f]
    regime_npv_centers = [-680_000.0, 520_000.0 * scale_f, 1_750_000.0 * scale_f, 3_650_000.0 * scale_f]

    exp_roi = sum(reg_probs[k] * regime_roi_centers[k] for k in 1:4)
    exp_npv = sum(reg_probs[k] * regime_npv_centers[k] for k in 1:4)
    prob_positive = (1.0 - reg_probs[1]) * 100.0
    prob_strong_or_better = (reg_probs[3] + reg_probs[4]) * 100.0

    # Stage-Gate Decision Rule
    gate_decision = if prob_strong_or_better >= 62.0 && reg_probs[1] < 0.08
        "GREEN LIGHT (Release Next-Stage Funding)"
    elseif prob_positive >= 75.0
        "FIX FIRST (Tighten Quality & Budget Before Scaling)"
    else
        "HOLD / PAUSE (Freeze New Seats & Fix Workflows)"
    end

    return Dict{String, Any}(
        "expected_roi_pct" => round(exp_roi, digits=1),
        "expected_npv_usd" => round(exp_npv, digits=0),
        "prob_positive_npv_pct" => round(prob_positive, digits=1),
        "prob_strong_or_outsized_roi_pct" => round(prob_strong_or_better, digits=1),
        "regime_probabilities_pct" => Dict{String, Float64}(
            "loss_below_0_pct" => round(reg_probs[1] * 100.0, digits=1),
            "modest_0_to_80_pct" => round(reg_probs[2] * 100.0, digits=1),
            "strong_80_to_160_pct" => round(reg_probs[3] * 100.0, digits=1),
            "outsized_above_160_pct" => round(reg_probs[4] * 100.0, digits=1)
        ),
        "node_posteriors_pct" => Dict{String, Vector{Float64}}(
            k => [round(x * 100.0, digits=1) for x in v] for (k, v) in beliefs
        ),
        "stage_gate_decision" => gate_decision
    )
end

"""
    run_bayesian_network_model(config::ScenarioConfig; obs_adoption::Int=0, obs_rework::Int=0, obs_token_control::Int=0)

Computes the Bayesian Network prior and precomputes a lookup table of posterior updates across key Month-6 pilot telemetry scenarios,
plus the exact posterior for any user-supplied `obs_*` evidence.
"""
function run_bayesian_network_model(
    config::ScenarioConfig;
    obs_adoption::Int=0,
    obs_rework::Int=0,
    obs_token_control::Int=0
)
    # Scenario-specific priors over Root 1 (ExecSupport) and Root 2 (GovernanceMaturity)
    prior_exec, prior_gov = if config.id == "agentic_transformation"
        ([0.08, 0.32, 0.60], [0.10, 0.35, 0.55])
    elseif config.id == "pragmatic_phased"
        ([0.12, 0.43, 0.45], [0.10, 0.45, 0.45])
    elseif config.id == "conservative_pilot"
        ([0.22, 0.50, 0.28], [0.06, 0.34, 0.60])
    else # blitzscale_mandate
        ([0.10, 0.30, 0.60], [0.62, 0.28, 0.10])
    end

    # 1. Unconditional Prior (Before Pilot Data)
    prior_beliefs = compute_bayesian_posterior(prior_exec, prior_gov, 0, 0, 0)
    prior_summary = summarize_posterior_metrics(config, prior_beliefs)

    # 2. Active Evidence Posterior (matches requested obs_* arguments)
    active_beliefs = compute_bayesian_posterior(prior_exec, prior_gov, obs_adoption, obs_rework, obs_token_control)
    active_summary = summarize_posterior_metrics(config, active_beliefs)

    # 3. Precompute key pilot telemetry presets for instant UI switching & comparison
    evidence_presets = [
        ("prior_unobserved", "Day-1 Estimate (Before Any Pilot Results)", (0, 0, 0)),
        ("strong_pilot", "Great 6-Month Pilot (High Usage + Low Cleanup + On-Budget)", (3, 3, 3)),
        ("mixed_pilot", "Average 6-Month Pilot (Moderate Usage + Moderate Cleanup + On-Budget)", (2, 2, 2)),
        ("sprawl_warning", "Busy But Messy Pilot (High Usage + Heavy Cleanup + Over-Budget)", (3, 1, 1)),
        ("stalled_pilot", "Struggling Pilot (Low Usage + Heavy Cleanup + Over-Budget)", (1, 1, 1))
    ]

    precomputed_posteriors = Vector{Dict{String, Any}}()
    for (preset_id, preset_label, (oa, orw, ot)) in evidence_presets
        b = compute_bayesian_posterior(prior_exec, prior_gov, oa, orw, ot)
        s = summarize_posterior_metrics(config, b)
        push!(precomputed_posteriors, Dict{String, Any}(
            "id" => preset_id,
            "label" => preset_label,
            "evidence" => Dict{String, Int}("adoption" => oa, "rework" => orw, "token_discipline" => ot),
            "summary" => s
        ))
    end

    dag_nodes = [
        Dict{String, Any}("id" => "exec_support", "label" => "Executive & Change Support", "layer" => 1, "states" => ["Weak", "Moderate", "Strong"]),
        Dict{String, Any}("id" => "governance", "label" => "AI Governance & Guardrails", "layer" => 1, "states" => ["Ad-Hoc", "Managed", "Automated"]),
        Dict{String, Any}("id" => "pilot_adoption", "label" => "M6 Pilot Adoption Signal", "layer" => 2, "states" => ["Low (<45%)", "Target (45-75%)", "High (>75%)"]),
        Dict{String, Any}("id" => "rework_signal", "label" => "QA Verification & Rework", "layer" => 2, "states" => ["High (>10%)", "Moderate (5-10%)", "Low (<5%)"]),
        Dict{String, Any}("id" => "token_discipline", "label" => "FinOps Token Discipline", "layer" => 2, "states" => ["Overrun", "On-Budget", "Optimized"]),
        Dict{String, Any}("id" => "sustained_realization", "label" => "Operating-Model Realization", "layer" => 3, "states" => ["Low", "Medium", "High"]),
        Dict{String, Any}("id" => "roi_regime", "label" => "3-Year Net ROI Regime", "layer" => 4, "states" => ["Loss (<0%)", "Modest (0-80%)", "Strong (80-160%)", "Outsized (>160%)"])
    ]

    dag_edges = [
        Dict{String, String}("from" => "exec_support", "to" => "pilot_adoption"),
        Dict{String, String}("from" => "exec_support", "to" => "sustained_realization"),
        Dict{String, String}("from" => "governance", "to" => "rework_signal"),
        Dict{String, String}("from" => "governance", "to" => "token_discipline"),
        Dict{String, String}("from" => "pilot_adoption", "to" => "sustained_realization"),
        Dict{String, String}("from" => "rework_signal", "to" => "sustained_realization"),
        Dict{String, String}("from" => "sustained_realization", "to" => "roi_regime"),
        Dict{String, String}("from" => "rework_signal", "to" => "roi_regime"),
        Dict{String, String}("from" => "token_discipline", "to" => "roi_regime")
    ]

    return Dict{String, Any}(
        "paradigm" => "bayesian_network",
        "scenario_id" => config.id,
        "scenario_name" => config.name,
        "priors" => Dict{String, Vector{Float64}}(
            "exec_support" => prior_exec,
            "governance" => prior_gov
        ),
        "prior_baseline" => prior_summary,
        "active_posterior" => active_summary,
        "evidence_presets" => precomputed_posteriors,
        "dag_structure" => Dict{String, Any}(
            "nodes" => dag_nodes,
            "edges" => dag_edges
        )
    )
end

