@testset "Core Utilities, Samplers & JSON Serializer (100% Coverage)" begin
    rng = MersenneTwister(12345)

    # 1. Triangular sampler: normal case + degenerate case (c <= a) + upper branch
    for _ in 1:100
        v = sample_triangular(rng, 10.0, 20.0, 50.0)
        @test 10.0 <= v <= 50.0
    end
    @test sample_triangular(rng, 25.0, 25.0, 25.0) == 25.0
    @test sample_triangular(rng, 30.0, 20.0, 10.0) == 30.0

    # 2. LogNormal sampler from P10/P90 CI
    ln_samples = [sample_lognormal_from_ci(rng, 100.0, 500.0) for _ in 1:2000]
    @test all(x -> x > 0.0, ln_samples)
    @test 80.0 <= quantile(ln_samples, 0.10) <= 130.0
    @test 400.0 <= quantile(ln_samples, 0.90) <= 620.0

    # 3. Logistic adoption & J-curve dip
    a_early = logistic_adoption(1, 0.85, 10.0, 0.5)
    a_mid = logistic_adoption(10, 0.85, 10.0, 0.5)
    a_late = logistic_adoption(36, 0.85, 10.0, 0.5)
    @test 0.0 < a_early < a_mid < a_late <= 0.85
    @test isapprox(a_mid, 0.425; atol=1e-6)

    d_peak = j_curve_dip(7, 9.5, 0.08)
    d_late = j_curve_dip(36, 9.5, 0.08)
    @test 0.0 < d_late < d_peak <= 0.08

    # 4. Quantile summary, matrix quantiles & histogram (including degenerate min==max edge case)
    vec = collect(1.0:100.0)
    qs = quantile_summary(vec; digits=2)
    @test qs["p10"] <= qs["p25"] <= qs["p50"] <= qs["p75"] <= qs["p90"]

    mat = reshape(collect(1.0:60.0), 10, 6)
    mq = matrix_quantiles(mat; digits=1)
    @test length(mq["p50"]) == 6

    hist_norm = build_histogram(vec, 10, 0.0, 100.0)
    @test sum(hist_norm["counts"]) == 100
    hist_flat = build_histogram(fill(5.0, 20), 5, 5.0, 5.0)
    @test sum(hist_flat["counts"]) == 20

    # 5. JSON Serializer (all types: Nothing, Bool, Integer, Float/NaN/Inf, String escapes, Symbol, empty/compact/nested Vector & Dict)
    io = IOBuffer()
    to_json(io, nothing)
    @test String(take!(io)) == "null"

    to_json(io, true)
    @test String(take!(io)) == "true"
    to_json(io, false)
    @test String(take!(io)) == "false"

    to_json(io, 42)
    @test String(take!(io)) == "42"

    to_json(io, NaN)
    @test String(take!(io)) == "null"
    to_json(io, Inf)
    @test String(take!(io)) == "null"
    to_json(io, 3.14)
    @test String(take!(io)) == "3.14"

    escaped = escape_json_string("quote\"slash\\newline\ncarriage\rtab\tend")
    @test occursin("\\\"", escaped)
    @test occursin("\\\\", escaped)
    @test occursin("\\n", escaped)
    @test occursin("\\r", escaped)
    @test occursin("\\t", escaped)

    to_json(io, :my_symbol)
    @test String(take!(io)) == "\"my_symbol\""

    to_json(io, Int[])
    @test String(take!(io)) == "[]"
    to_json(io, [1, 2, 3])
    @test String(take!(io)) == "[1, 2, 3]"
    to_json(io, ["a", "b"])
    @test occursin("\"a\"", String(take!(io)))

    to_json(io, Dict{String, Any}())
    @test String(take!(io)) == "{}"

    tmp_file = tempname() * ".json"
    write_json(tmp_file, Dict("a" => 1, "b" => [10, 20]))
    @test isfile(tmp_file)
    rm(tmp_file; force=true)

    # 6. Verify all underlined terms in web/index.html, web/lab.html, web/app.js, web/lab.js map to <=60-word tooltips in web/tooltips.js
    tooltips_js = read(joinpath(@__DIR__, "..", "web", "tooltips.js"), String)
    glossary_keys = Set(m.captures[1] for m in eachmatch(r"^\s*([a-z0-9_]+):\s*\"([^\"]+)\""m, tooltips_js))
    @test length(glossary_keys) >= 30

    for m in eachmatch(r"^\s*([a-z0-9_]+):\s*\"([^\"]+)\""m, tooltips_js)
        word_count = length(split(strip(m.captures[2])))
        @test 5 <= word_count <= 60
    end

    for web_file in ("index.html", "lab.html", "app.js", "lab.js")
        src = read(joinpath(@__DIR__, "..", "web", web_file), String)
        for m in eachmatch(r"data-term-key=\"([^\"]+)\"", src)
            @test m.captures[1] in glossary_keys
        end
        for m in eachmatch(r"\bt\(\s*\"([^\"]+)\"", src)
            @test m.captures[1] in glossary_keys
        end
    end

    # 7. Verify interactive sub-window buttons across all 5 panes and 1-second fade animation helper
    index_html = read(joinpath(@__DIR__, "..", "web", "index.html"), String)
    app_js = read(joinpath(@__DIR__, "..", "web", "app.js"), String)
    @test occursin("data-traj=", index_html)
    @test occursin("data-dist=", index_html)
    @test occursin("data-abm-view=", index_html)
    @test occursin("data-abm-dept=", index_html)
    @test occursin("data-sd-stock=", index_html)
    @test occursin("data-sd-flow=", index_html)
    @test occursin("data-des-traj=", index_html)
    @test occursin("data-des-bar=", index_html)
    @test occursin("data-bn-view=", index_html)
    @test occursin("animateFadeSwap", tooltips_js)
    @test occursin("fadeSwap", app_js)

    # 8. Verify in-UI Markdown modal viewer (`data-open-md`, `renderMarkdownToHtml`) and auto-shutdown server script
    @test occursin("data-open-md=\"monte_carlo\"", index_html)
    @test occursin("data-open-md=\"agent_based\"", index_html)
    @test occursin("data-open-md=\"system_dynamics\"", index_html)
    @test occursin("data-open-md=\"discrete_event\"", index_html)
    @test occursin("data-open-md=\"bayesian_network\"", index_html)
    @test occursin("renderMarkdownToHtml", tooltips_js)
    @test occursin("/__tab_closed", tooltips_js)
    @test isfile(joinpath(@__DIR__, "..", "scripts", "serve_web.py"))

    # 9. Verify per-tab inline rendered Markdown cards, vivid Mermaid diagrams, 2s fade animations, and tab panel pointer isolation
    lab_html = read(joinpath(@__DIR__, "..", "web", "lab.html"), String)
    styles_css = read(joinpath(@__DIR__, "..", "web", "styles.css"), String)
    for pid in ("monte_carlo", "agent_based", "system_dynamics", "discrete_event", "bayesian_network")
        @test occursin("id=\"md-inline-$(pid)\"", index_html)
    end
    for folder in ("monte-carlo", "agent-based", "system-dynamics", "discrete-event", "bayesian-network")
        @test !occursin("explanations/$(folder)/explanations.md", index_html)
        @test !occursin("explanations/$(folder)/explanations.md", lab_html)
        md_path = joinpath(@__DIR__, "..", "src", "simulations", folder, "explanations.md")
        @test isfile(md_path)
        md_txt = read(md_path, String)
        @test occursin("```mermaid", md_txt)
        @test occursin("style ", md_txt)
    end
    @test !occursin("id=\"explanations-section\"", index_html)
    @test !occursin("id=\"explanations-section\"", lab_html)
    @test occursin("renderInlineTabGuides", tooltips_js)
    @test occursin("totalDurationMs = 2000", tooltips_js)
    @test occursin("svgTipAttrs", app_js)
    @test occursin("pointer-events: none", styles_css)
end

