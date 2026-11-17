@testset "Paradigm 5: Bayesian Network (BN) Belief Propagation Engine" begin
    for sc in DEFAULT_SCENARIOS
        bn = run_bayesian_network_model(sc)
        @test bn["paradigm"] == "bayesian_network"
        @test length(bn["evidence_presets"]) == 5
        @test length(bn["dag_structure"]["nodes"]) == 7
        @test length(bn["dag_structure"]["edges"]) == 9

        # Check probability simplex sums to 100%
        reg = bn["prior_baseline"]["regime_probabilities_pct"]
        total_p = reg["loss_below_0_pct"] + reg["modest_0_to_80_pct"] + reg["strong_80_to_160_pct"] + reg["outsized_above_160_pct"]
        @test isapprox(total_p, 100.0; atol=0.5)
    end

    # Monotonicity under positive vs negative pilot evidence
    sc = DEFAULT_SCENARIOS[1]
    bn_favorable = run_bayesian_network_model(sc; obs_adoption=3, obs_rework=3, obs_token_control=3)
    bn_unfavorable = run_bayesian_network_model(sc; obs_adoption=1, obs_rework=1, obs_token_control=1)

    fav_roi = bn_favorable["active_posterior"]["expected_roi_pct"]
    unfav_roi = bn_unfavorable["active_posterior"]["expected_roi_pct"]
    @test fav_roi > unfav_roi
    @test bn_favorable["active_posterior"]["prob_positive_npv_pct"] > bn_unfavorable["active_posterior"]["prob_positive_npv_pct"]
    @test occursin("GREEN LIGHT", bn_favorable["active_posterior"]["stage_gate_decision"])
    @test occursin("HOLD", bn_unfavorable["active_posterior"]["stage_gate_decision"])
end

