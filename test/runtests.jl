using Test
using Random
using Statistics

include(joinpath(@__DIR__, "..", "src", "AIROISimulator.jl"))
using .AIROISimulator

@testset "AIROISimulator Comprehensive 5-Paradigm Test Suite" begin
    include("test_core.jl")
    include("test_monte_carlo.jl")
    include("test_agent_based.jl")
    include("test_system_dynamics.jl")
    include("test_discrete_event.jl")
    include("test_bayesian_network.jl")

    @testset "Full Multi-Paradigm Suite Integration (`run_all_scenarios`)" begin
        bundle = run_multi_paradigm_suite(n_trials=300, n_abm_reps=20, horizon_months=36, base_seed=42)
        @test bundle["schema_version"] == "2.0.0"
        @test length(bundle["paradigms_metadata"]) == 5
        @test length(bundle["scenarios"]) == 4

        for sc in bundle["scenarios"]
            @test haskey(sc, "paradigms")
            @test haskey(sc["paradigms"], "monte_carlo")
            @test haskey(sc["paradigms"], "agent_based")
            @test haskey(sc["paradigms"], "system_dynamics")
            @test haskey(sc["paradigms"], "discrete_event")
            @test haskey(sc["paradigms"], "bayesian_network")
            @test length(sc["cross_paradigm_comparison"]) == 5
        end
    end
end
