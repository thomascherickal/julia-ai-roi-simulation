@testset "Paradigm 1: Monte Carlo Financial Risk Engine" begin
    sc = DEFAULT_SCENARIOS[1]
    res1 = run_monte_carlo(sc; n_trials=800, horizon_months=36, seed=77)
    res2 = run_simulation(sc; n_trials=800, horizon_months=36, seed=77)

    # Exact seed determinism & alias verification
    @test res1["kpis"]["roi_pct"]["p50"] == res2["kpis"]["roi_pct"]["p50"]
    @test res1["kpis"]["npv_usd"]["p10"] == res2["kpis"]["npv_usd"]["p10"]

    for scenario in DEFAULT_SCENARIOS
        r = run_monte_carlo(scenario; n_trials=600, horizon_months=36, seed=101)
        roi = r["kpis"]["roi_pct"]
        npv = r["kpis"]["npv_usd"]
        @test roi["p05"] <= roi["p10"] <= roi["p25"] <= roi["p50"] <= roi["p75"] <= roi["p90"] <= roi["p95"]
        @test npv["p05"] <= npv["p10"] <= npv["p25"] <= npv["p50"] <= npv["p75"] <= npv["p90"] <= npv["p95"]
        @test (roi["p90"] - roi["p10"]) > 15.0
        @test length(r["teams"]) == 4
        @test length(r["sensitivity"]) == 6
    end
end

