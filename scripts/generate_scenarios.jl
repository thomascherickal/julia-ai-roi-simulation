#!/usr/bin/env julia

using Printf

include(joinpath(@__DIR__, "..", "src", "AIROISimulator.jl"))
using .AIROISimulator

function main()
    n_trials = 10_000
    n_abm_reps = 160
    horizon_months = 36
    base_seed = 20261116

    println("="^92)
    println("Multi-Paradigm AI Adoption ROI Simulator — Precomputing All 5 Scientific Models")
    println("1. Monte Carlo Risk    : $(n_trials) trials/scenario")
    println("2. Agent-Based (ABM)   : $(n_abm_reps) replications × 325 network actors")
    println("3. System Dynamics     : Coupled 4-stock RK4 differential equation solver")
    println("4. Discrete Event (DES): 3-stage departmental work queues & QA server bottlenecks")
    println("5. Bayesian Network    : Exact 7-node DAG belief propagation & stage-gate updater")
    println("="^92)

    t_start = time()
    bundle = run_all_scenarios(
        n_trials=n_trials,
        n_abm_reps=n_abm_reps,
        horizon_months=horizon_months,
        base_seed=base_seed
    )
    elapsed = round(time() - t_start, digits=2)

    out_dir = joinpath(@__DIR__, "..", "web", "data")
    mkpath(out_dir)

    bundle_path = joinpath(out_dir, "scenarios.json")
    write_json(bundle_path, bundle)

    # Also write a JS bundle for zero-CORS `file://` opening
    bundle_js_path = joinpath(out_dir, "scenarios-bundle.js")
    write(bundle_js_path, "window.PRECOMPUTED_SCENARIOS_BUNDLE = " * read(bundle_path, String) * ";\n")

    # Also copy each simulation's explanations.md into web/explanations/<paradigm_id>/explanations.md for direct HTTP serving
    expl_map = [
        ("monte_carlo", "monte-carlo"),
        ("agent_based", "agent-based"),
        ("system_dynamics", "system-dynamics"),
        ("discrete_event", "discrete-event"),
        ("bayesian_network", "bayesian-network")
    ]
    for (pid, folder) in expl_map
        src_md = joinpath(@__DIR__, "..", "src", "simulations", folder, "explanations.md")
        dst_dir = joinpath(@__DIR__, "..", "web", "explanations", folder)
        mkpath(dst_dir)
        cp(src_md, joinpath(dst_dir, "explanations.md"); force=true)
    end

    for sc in bundle["scenarios"]
        sc_id = sc["id"]
        write_json(joinpath(out_dir, "$(sc_id).json"), sc)

        p = sc["paradigms"]
        mc_roi = sc["kpis"]["roi_pct"]["p50"]
        abm_roi = p["agent_based"]["kpis"]["emergent_roi_pct"]["p50"]
        sd_roi = p["system_dynamics"]["kpis"]["equilibrium_roi_pct"]
        des_roi = p["discrete_event"]["kpis"]["process_roi_pct"]
        bn_roi = p["bayesian_network"]["prior_baseline"]["expected_roi_pct"]

        @printf(
            " • %-32s | MC: %+6.1f%% | ABM: %+6.1f%% | SD: %+6.1f%% | DES: %+6.1f%% | BN: %+6.1f%%\n",
            sc["name"], mc_roi, abm_roi, sd_roi, des_roi, bn_roi
        )
    end

    println("-"^92)
    println("Completed in $(elapsed)s. Static JSON written to: $(abspath(out_dir))")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
