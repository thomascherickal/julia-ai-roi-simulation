@testset "Paradigm 2: Agent-Based Modeling (ABM) Engine" begin
    for sc in DEFAULT_SCENARIOS
        abm = run_agent_based_model(sc; n_replications=40, horizon_months=36, seed=555)
        @test abm["paradigm"] == "agent_based"
        @test abm["parameters"]["total_agents"] == 325

        # Verify state fractions sum to ~100% at every month across the mean trajectory
        st = abm["state_trajectories"]
        for m in 1:36
            total_pct = st["skeptical_pct"]["mean"][m] +
                        st["exploring_pct"]["mean"][m] +
                        st["proficient_pct"]["mean"][m] +
                        st["champion_pct"]["mean"][m] +
                        st["disillusioned_pct"]["mean"][m]
            @test isapprox(total_pct, 100.0; atol=0.5)
        end

        # Verify network snapshot nodes & edges exist
        @test length(abm["network_snapshot"]["nodes"]) == 48
        @test !isempty(abm["network_snapshot"]["edges"])
    end

    # Test explicit parameter overrides: high champion seeding vs zero champion seeding
    sc = DEFAULT_SCENARIOS[1]
    abm_low_seed = run_agent_based_model(sc; n_replications=30, seed=99, champion_seed_fraction=0.01, peer_contagion_strength=0.20, frustration_sensitivity=0.25)
    abm_high_seed = run_agent_based_model(sc; n_replications=30, seed=99, champion_seed_fraction=0.15, peer_contagion_strength=0.55, frustration_sensitivity=0.03)

    @test abm_high_seed["kpis"]["m36_active_adopters_pct"]["p50"] > abm_low_seed["kpis"]["m36_active_adopters_pct"]["p50"]
    @test abm_high_seed["kpis"]["m36_disillusioned_churn_pct"]["p50"] < abm_low_seed["kpis"]["m36_disillusioned_churn_pct"]["p50"]
end

