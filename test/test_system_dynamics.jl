@testset "Paradigm 3: System Dynamics (SD) Stock-and-Flow Engine" begin
    for sc in DEFAULT_SCENARIOS
        sd = run_system_dynamics_model(sc; horizon_months=36, dt=0.25)
        @test sd["paradigm"] == "system_dynamics"
        @test length(sd["causal_loops"]) == 4

        sf = sd["stocks_and_flows"]
        @test length(sf["months"]) == 36
        @test all(x -> 0.0 <= x <= 100.0, sf["stock_adopted_workforce_pct"])
        @test all(x -> x >= 1.0, sf["stock_token_sprawl_multiplier"])
    end

    # Verify parameter sensitivity: high reinvestment & governance damping vs low
    sc = DEFAULT_SCENARIOS[1]
    sd_strong = run_system_dynamics_model(sc; reinvestment_rate=0.45, governance_damping=0.50, automation_ambition=0.50)
    sd_weak = run_system_dynamics_model(sc; reinvestment_rate=0.05, governance_damping=0.05, automation_ambition=0.50)

    @test sd_strong["kpis"]["m36_workflow_mastery_index"] > sd_weak["kpis"]["m36_workflow_mastery_index"]
    @test sd_strong["kpis"]["m36_tech_debt_index"] < sd_weak["kpis"]["m36_tech_debt_index"]
    @test sd_strong["kpis"]["m36_token_sprawl_multiplier"] < sd_weak["kpis"]["m36_token_sprawl_multiplier"]
    @test sd_strong["kpis"]["equilibrium_roi_pct"] > sd_weak["kpis"]["equilibrium_roi_pct"]
end

