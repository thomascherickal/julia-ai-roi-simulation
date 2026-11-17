@testset "Paradigm 4: Discrete Event Simulation (DES) Queueing Engine" begin
    rng = MersenneTwister(2026)

    # Edge case: 0 items or 0 servers
    w0, s0, p0, u0 = simulate_stage_queue(rng, 0, 5, 2.0, 1.0)
    @test w0 == 0.0 && u0 == 0.0

    # Queue congestion test: fewer servers -> higher utilization and longer wait time
    w_many_srv, _, _, u_many_srv = simulate_stage_queue(MersenneTwister(11), 400, 12, 2.5, 3.0)
    w_few_srv, _, _, u_few_srv = simulate_stage_queue(MersenneTwister(11), 400, 4, 2.5, 3.0)
    @test u_few_srv > u_many_srv
    @test w_few_srv >= w_many_srv

    for sc in DEFAULT_SCENARIOS
        des = run_discrete_event_model(sc; horizon_months=36, seed=808)
        @test des["paradigm"] == "discrete_event"
        @test length(des["workflows"]) == 4
        @test des["kpis"]["total_hours_saved_36m"] > 0.0
    end

    # Verify QA capacity reallocation reduces Month-36 QA wait time
    sc_blitz = DEFAULT_SCENARIOS[2] # blitzscale_mandate
    des_no_realloc = run_discrete_event_model(sc_blitz; seed=42, qa_capacity_reallocation=0.0)
    des_with_realloc = run_discrete_event_model(sc_blitz; seed=42, qa_capacity_reallocation=0.10)
    @test des_with_realloc["kpis"]["m36_qa_queue_wait_hrs"] <= des_no_realloc["kpis"]["m36_qa_queue_wait_hrs"]
end

