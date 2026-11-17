module AIROISimulator

using Random
using Statistics
using LinearAlgebra

# Shared Core Exports
export TeamArchetype, RolloutProfile, CostDynamics, ScenarioConfig
export DEFAULT_TEAMS, DEFAULT_SCENARIOS
export sample_triangular, sample_lognormal_from_ci, logistic_adoption, j_curve_dip
export quantile_summary, matrix_quantiles, build_histogram
export escape_json_string, to_json, write_json

# 5 Scientific Simulation Paradigm Exports
export run_monte_carlo, run_simulation, compute_driver_sensitivity
export run_agent_based_model
export run_system_dynamics_model
export DESWorkflowSpec, DEFAULT_DES_WORKFLOWS, simulate_stage_queue, run_discrete_event_model
export compute_bayesian_posterior, summarize_posterior_metrics, run_bayesian_network_model
export run_all_scenarios, run_multi_paradigm_suite

# 1. Include Modular Core
include("core/types.jl")
include("core/math_utils.jl")
include("core/scenarios.jl")
include("core/json_serializer.jl")

# 2. Include All 5 Scientific Simulation Modules
include("simulations/monte-carlo/MonteCarloModel.jl")
include("simulations/agent-based/AgentBasedModel.jl")
include("simulations/system-dynamics/SystemDynamicsModel.jl")
include("simulations/discrete-event/DiscreteEventModel.jl")
include("simulations/bayesian-network/BayesianNetworkModel.jl")

# Backward-compatible alias for `run_monte_carlo`
const run_simulation = run_monte_carlo

"""
    run_all_scenarios(; n_trials::Int=10_000, n_abm_reps::Int=160, horizon_months::Int=36, base_seed::Int=20261116)

Executes all 5 scientific simulation paradigms across all 4 canonical Board scenarios,
returning a unified dictionary bundle ready for static JSON export.
"""
function run_all_scenarios(; n_trials::Int=10_000, n_abm_reps::Int=160, horizon_months::Int=36, base_seed::Int=20261116)
    scenarios_out = Vector{Dict{String, Any}}()

    for (idx, sc) in enumerate(DEFAULT_SCENARIOS)
        mc_res = run_monte_carlo(sc; n_trials=n_trials, horizon_months=horizon_months, seed=base_seed + idx * 101)
        abm_res = run_agent_based_model(sc; n_replications=n_abm_reps, horizon_months=horizon_months, seed=base_seed + idx * 202)
        sd_res = run_system_dynamics_model(sc; horizon_months=horizon_months)
        des_res = run_discrete_event_model(sc; horizon_months=horizon_months, seed=base_seed + idx * 303)
        bn_res = run_bayesian_network_model(sc)

        # Attach all 5 paradigm results to each scenario object while preserving top-level Monte Carlo keys
        mc_res["paradigms"] = Dict{String, Any}(
            "monte_carlo" => Dict{String, Any}(
                "kpis" => mc_res["kpis"],
                "trajectories" => mc_res["trajectories"],
                "distributions" => mc_res["distributions"],
                "sensitivity" => mc_res["sensitivity"],
                "teams" => mc_res["teams"]
            ),
            "agent_based" => abm_res,
            "system_dynamics" => sd_res,
            "discrete_event" => des_res,
            "bayesian_network" => bn_res
        )

        # Cross-paradigm synthesis table for this scenario
        mc_res["cross_paradigm_comparison"] = [
            Dict{String, Any}(
                "paradigm_id" => "monte_carlo",
                "paradigm_name" => "1. 10,000 What-If Futures (Monte Carlo)",
                "mechanism" => "Tests 10,000 combinations of adoption speed, time saved, and costs",
                "central_roi_pct" => mc_res["kpis"]["roi_pct"]["p50"],
                "downside_roi_pct" => mc_res["kpis"]["roi_pct"]["p10"],
                "upside_roi_pct" => mc_res["kpis"]["roi_pct"]["p90"],
                "central_npv_usd" => mc_res["kpis"]["npv_usd"]["p50"],
                "primary_insight" => "Shows honest Cautious (P10) to Best-Case (P90) profit ranges and breakeven speed."
            ),
            Dict{String, Any}(
                "paradigm_id" => "agent_based",
                "paradigm_name" => "2. Team Behavior (Agent-Based)",
                "mechanism" => "Follows 325 individual coworkers sharing tips or quitting in frustration",
                "central_roi_pct" => abm_res["kpis"]["emergent_roi_pct"]["p50"],
                "downside_roi_pct" => abm_res["kpis"]["emergent_roi_pct"]["p10"],
                "upside_roi_pct" => abm_res["kpis"]["emergent_roi_pct"]["p90"],
                "central_npv_usd" => abm_res["kpis"]["emergent_npv_usd"]["p50"],
                "primary_insight" => "Shows how AI Champions spread good habits while $(abm_res["kpis"]["m36_disillusioned_churn_pct"]["p50"])% of seats risk becoming unused shelfware."
            ),
            Dict{String, Any}(
                "paradigm_id" => "system_dynamics",
                "paradigm_name" => "3. Flywheels & Brakes (System Dynamics)",
                "mechanism" => "Tracks growing company know-how against cleanup backlog and rising bills",
                "central_roi_pct" => sd_res["kpis"]["equilibrium_roi_pct"],
                "downside_roi_pct" => round(sd_res["kpis"]["equilibrium_roi_pct"] * 0.62, digits=1),
                "upside_roi_pct" => round(sd_res["kpis"]["equilibrium_roi_pct"] * 1.38, digits=1),
                "central_npv_usd" => sd_res["kpis"]["equilibrium_npv_usd"],
                "primary_insight" => "Weighs growing team know-how ($(sd_res["kpis"]["m36_workflow_mastery_index"]) pts) against monthly bill growth ($(sd_res["kpis"]["m36_token_sprawl_multiplier"])x)."
            ),
            Dict{String, Any}(
                "paradigm_id" => "discrete_event",
                "paradigm_name" => "4. Workflow Waiting Lines (Discrete Event)",
                "mechanism" => "Follows everyday work items from first draft to final human review",
                "central_roi_pct" => des_res["kpis"]["process_roi_pct"],
                "downside_roi_pct" => round(des_res["kpis"]["process_roi_pct"] * 0.65, digits=1),
                "upside_roi_pct" => round(des_res["kpis"]["process_roi_pct"] * 1.35, digits=1),
                "central_npv_usd" => des_res["kpis"]["process_npv_usd"],
                "primary_insight" => "Cuts turnaround time by $(des_res["kpis"]["cycle_time_reduction_pct"])% while checking if final human review lines back up ($(des_res["kpis"]["m36_qa_queue_wait_hrs"])h wait)."
            ),
            Dict{String, Any}(
                "paradigm_id" => "bayesian_network",
                "paradigm_name" => "5. Pilot Scorecard (Bayesian Network)",
                "mechanism" => "Updates 3-year profit odds as soon as 6-month pilot results arrive",
                "central_roi_pct" => bn_res["prior_baseline"]["expected_roi_pct"],
                "downside_roi_pct" => bn_res["evidence_presets"][5]["summary"]["expected_roi_pct"],
                "upside_roi_pct" => bn_res["evidence_presets"][2]["summary"]["expected_roi_pct"],
                "central_npv_usd" => bn_res["prior_baseline"]["expected_npv_usd"],
                "primary_insight" => "Next-stage funding call: $(bn_res["prior_baseline"]["stage_gate_decision"])."
            )
        ]

        push!(scenarios_out, mc_res)
    end

    return Dict{String, Any}(
        "schema_version" => "2.0.0",
        "model_title" => "Multi-Paradigm Scientific AI Adoption ROI Simulator",
        "model_subtitle" => "5 Science-Based Forecasting Approaches Modeling the Canonical 325-FTE Enterprise Rollout",
        "generated_by" => "Julia $(VERSION) — AIROISimulator.jl (MC + ABM + SD + DES + BN)",
        "default_scenario_id" => "pragmatic_phased",
        "paradigms_metadata" => [
            Dict{String, String}(
                "id" => "monte_carlo",
                "tab_title" => "1. Monte Carlo Risk",
                "core_concept" => "Top-down correlated probability distributions",
                "captures" => "Honest P10–P50–P90 financial confidence bands & tail risk",
                "best_for" => "Board capital allocation, NPV at WACC & downside stress-testing",
                "explanation_path" => "src/simulations/monte-carlo/explanations.md",
                "explanation_markdown" => read(joinpath(@__DIR__, "simulations", "monte-carlo", "explanations.md"), String)
            ),
            Dict{String, String}(
                "id" => "agent_based",
                "tab_title" => "2. Agent-Based (ABM)",
                "core_concept" => "Bottom-up interaction of individual actors",
                "captures" => "Employee adoption friction, champion contagion & behavioral churn",
                "best_for" => "Deploying AI copilots and customer-facing bots",
                "explanation_path" => "src/simulations/agent-based/explanations.md",
                "explanation_markdown" => read(joinpath(@__DIR__, "simulations", "agent-based", "explanations.md"), String)
            ),
            Dict{String, String}(
                "id" => "system_dynamics",
                "tab_title" => "3. System Dynamics",
                "core_concept" => "Macro-level feedback loops, stocks, and flows",
                "captures" => "Compounding workflow mastery vs. tech debt & scaling compute costs",
                "best_for" => "Multi-year AI strategy and infrastructure scaling",
                "explanation_path" => "src/simulations/system-dynamics/explanations.md",
                "explanation_markdown" => read(joinpath(@__DIR__, "simulations", "system-dynamics", "explanations.md"), String)
            ),
            Dict{String, String}(
                "id" => "discrete_event",
                "tab_title" => "4. Discrete Event (DES)",
                "core_concept" => "Step-by-step process queues and resource limits",
                "captures" => "Exact cycle time saved, SLA queues & human QA review bottlenecks",
                "best_for" => "Automating support desks, PR reviews, logistics, or claims",
                "explanation_path" => "src/simulations/discrete-event/explanations.md",
                "explanation_markdown" => read(joinpath(@__DIR__, "simulations", "discrete-event", "explanations.md"), String)
            ),
            Dict{String, String}(
                "id" => "bayesian_network",
                "tab_title" => "5. Bayesian Network",
                "core_concept" => "Conditional probability graphs updated with data",
                "captures" => "Dynamically adjusts ROI forecasts using Month-6 pilot telemetry",
                "best_for" => "Risk management and stage-gate funding decisions",
                "explanation_path" => "src/simulations/bayesian-network/explanations.md",
                "explanation_markdown" => read(joinpath(@__DIR__, "simulations", "bayesian-network", "explanations.md"), String)
            )
        ],
        "scenarios" => scenarios_out
    )
end

const run_multi_paradigm_suite = run_all_scenarios

end # module AIROISimulator
