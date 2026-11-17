# Paradigm 1: Top-Down Financial Risk Monte Carlo Engine

function compute_driver_sensitivity(
    label::String,
    category::String,
    driver::Vector{Float64},
    roi_pct::Vector{Float64},
    npv_usd::Vector{Float64}
)
    r_corr = cor(driver, npv_usd)
    q20 = quantile(driver, 0.20)
    q80 = quantile(driver, 0.80)

    low_idx = driver .<= q20
    high_idx = driver .>= q80

    npv_at_low_driver = median(view(npv_usd, low_idx))
    npv_at_high_driver = median(view(npv_usd, high_idx))
    roi_at_low_driver = median(view(roi_pct, low_idx))
    roi_at_high_driver = median(view(roi_pct, high_idx))

    npv_swing = npv_at_high_driver - npv_at_low_driver
    roi_swing = roi_at_high_driver - roi_at_low_driver

    return Dict{String, Any}(
        "driver" => label,
        "category" => category,
        "spearman_r" => round(r_corr, digits=3),
        "npv_low_driver_usd" => round(npv_at_low_driver, digits=0),
        "npv_high_driver_usd" => round(npv_at_high_driver, digits=0),
        "npv_swing_usd" => round(npv_swing, digits=0),
        "roi_low_driver_pct" => round(roi_at_low_driver, digits=1),
        "roi_high_driver_pct" => round(roi_at_high_driver, digits=1),
        "roi_swing_pct" => round(roi_swing, digits=1)
    )
end

"""
    run_monte_carlo(config::ScenarioConfig; n_trials::Int=10_000, horizon_months::Int=36, seed::Int=20261116)

Runs a correlated top-down Monte Carlo simulation of `n_trials` over `horizon_months` for `config`.
"""
function run_monte_carlo(config::ScenarioConfig; n_trials::Int=10_000, horizon_months::Int=36, seed::Int=20261116)
    rng = MersenneTwister(seed)
    n_teams = length(config.teams)
    total_headcount = sum(t.headcount for t in config.teams)
    total_annual_payroll = sum(t.headcount * t.fully_loaded_annual_cost_usd for t in config.teams)

    trial_npv = Vector{Float64}(undef, n_trials)
    trial_roi_pct = Vector{Float64}(undef, n_trials)
    trial_payback_month = Vector{Float64}(undef, n_trials)
    trial_total_cost = Vector{Float64}(undef, n_trials)
    trial_total_gross_benefit = Vector{Float64}(undef, n_trials)
    trial_total_rework_cost = Vector{Float64}(undef, n_trials)
    trial_total_net_benefit = Vector{Float64}(undef, n_trials)
    trial_month36_adoption = Vector{Float64}(undef, n_trials)
    trial_month36_net_uplift = Vector{Float64}(undef, n_trials)

    driver_rollout_speed = Vector{Float64}(undef, n_trials)
    driver_gross_uplift = Vector{Float64}(undef, n_trials)
    driver_rework_drag = Vector{Float64}(undef, n_trials)
    driver_realization = Vector{Float64}(undef, n_trials)
    driver_platform_cost = Vector{Float64}(undef, n_trials)
    driver_token_cost_drift = Vector{Float64}(undef, n_trials)

    monthly_cum_cashflow = Matrix{Float64}(undef, n_trials, horizon_months)
    monthly_net_cashflow = Matrix{Float64}(undef, n_trials, horizon_months)
    monthly_adoption = Matrix{Float64}(undef, n_trials, horizon_months)
    monthly_eff_productivity = Matrix{Float64}(undef, n_trials, horizon_months)
    monthly_cost_runrate = Matrix{Float64}(undef, n_trials, horizon_months)
    monthly_benefit_runrate = Matrix{Float64}(undef, n_trials, horizon_months)

    team_trial_roi = Matrix{Float64}(undef, n_trials, n_teams)
    team_trial_net_benefit = Matrix{Float64}(undef, n_trials, n_teams)
    team_trial_cost = Matrix{Float64}(undef, n_trials, n_teams)
    team_trial_net_uplift = Matrix{Float64}(undef, n_trials, n_teams)
    team_trial_hours_saved_per_emp = Matrix{Float64}(undef, n_trials, n_teams)

    monthly_discount_rate = (1.0 + config.costs.annual_discount_rate)^(1.0 / 12.0) - 1.0

    for trial in 1:n_trials
        ceiling_org = sample_triangular(rng, config.rollout.ceiling_min, config.rollout.ceiling_mode, config.rollout.ceiling_max)
        t0_org = sample_triangular(rng, config.rollout.inflection_month_min, config.rollout.inflection_month_mode, config.rollout.inflection_month_max)
        k_org = sample_triangular(rng, config.rollout.steepness_min, config.rollout.steepness_mode, config.rollout.steepness_max)
        dip_org = sample_triangular(rng, config.rollout.dip_depth_min, config.rollout.dip_depth_mode, config.rollout.dip_depth_max)

        upfront_platform = sample_lognormal_from_ci(rng, config.costs.upfront_platform_p10_usd, config.costs.upfront_platform_p90_usd)
        training_per_seat = sample_triangular(rng, config.costs.training_per_seat_min_usd, config.costs.training_per_seat_mode_usd, config.costs.training_per_seat_max_usd)
        token_drift_annual = sample_triangular(rng, config.costs.token_drift_annual_min, config.costs.token_drift_annual_mode, config.costs.token_drift_annual_max)
        monthly_token_drift = (1.0 + token_drift_annual)^(1.0 / 12.0) - 1.0

        t_gross = Vector{Float64}(undef, n_teams)
        t_rework = Vector{Float64}(undef, n_teams)
        t_seat_cost = Vector{Float64}(undef, n_teams)
        t_realization = Vector{Float64}(undef, n_teams)
        t_t0 = Vector{Float64}(undef, n_teams)
        t_ceiling = Vector{Float64}(undef, n_teams)

        weighted_gross = 0.0
        weighted_rework = 0.0
        weighted_realization = 0.0
        weighted_seat_cost = 0.0

        for i in 1:n_teams
            tm = config.teams[i]
            g = sample_triangular(rng, tm.gross_uplift_min, tm.gross_uplift_mode, tm.gross_uplift_max) * config.uplift_multiplier
            r = sample_triangular(rng, tm.rework_drag_min, tm.rework_drag_mode, tm.rework_drag_max) * config.rework_multiplier
            sc = sample_triangular(rng, tm.seat_cost_monthly_min, tm.seat_cost_monthly_mode, tm.seat_cost_monthly_max) * config.seat_cost_multiplier
            real_f = clamp(
                sample_triangular(rng, tm.realization_factor_min, tm.realization_factor_mode, tm.realization_factor_max) * config.realization_multiplier,
                0.10, 0.98
            )
            t_t0[i] = clamp(t0_org + 0.8 * randn(rng), 2.0, 28.0)
            t_ceiling[i] = clamp(ceiling_org + 0.03 * randn(rng), 0.25, 0.99)

            t_gross[i] = g
            t_rework[i] = r
            t_seat_cost[i] = sc
            t_realization[i] = real_f

            w = tm.headcount / total_headcount
            weighted_gross += w * g * tm.ai_addressable_task_share
            weighted_rework += w * r
            weighted_realization += w * real_f
            weighted_seat_cost += w * sc
        end

        driver_rollout_speed[trial] = -t0_org
        driver_gross_uplift[trial] = weighted_gross
        driver_rework_drag[trial] = weighted_rework
        driver_realization[trial] = weighted_realization
        driver_platform_cost[trial] = upfront_platform + training_per_seat * total_headcount
        driver_token_cost_drift[trial] = weighted_seat_cost * (1.0 + token_drift_annual)

        cum_cf = 0.0
        npv_acc = 0.0
        tot_cost = 0.0
        tot_gross_ben = 0.0
        tot_rework_cost = 0.0
        tot_net_ben = 0.0

        payback_m = Float64(horizon_months + 1)
        prev_cum_cf = 0.0

        for i in 1:n_teams
            team_trial_net_benefit[trial, i] = 0.0
            team_trial_cost[trial, i] = 0.0
            team_trial_hours_saved_per_emp[trial, i] = 0.0
        end

        for m in 1:horizon_months
            platform_m = if m <= 4
                0.25 * upfront_platform
            else
                (upfront_platform * config.costs.ongoing_platform_maint_rate) / 12.0
            end

            training_m = if m <= 9
                (training_per_seat * total_headcount) / 9.0
            else
                (training_per_seat * total_headcount * 0.15) / 12.0
            end

            shared_overhead_m = platform_m + training_m
            token_inflation_factor = (1.0 + monthly_token_drift)^(m - 1)

            m_cost = shared_overhead_m
            m_gross_ben = 0.0
            m_rework_c = 0.0
            m_net_ben = 0.0
            m_weighted_adopt = 0.0
            m_weighted_eff_prod = 0.0

            for i in 1:n_teams
                tm = config.teams[i]
                hc = Float64(tm.headcount)
                monthly_salary_per_emp = tm.fully_loaded_annual_cost_usd / 12.0
                team_payroll_m = hc * monthly_salary_per_emp

                adopt_m = logistic_adoption(m, t_ceiling[i], t_t0[i], k_org)
                dip_m = j_curve_dip(m, t_t0[i], dip_org)

                gross_task_gain = tm.ai_addressable_task_share * t_gross[i]
                rework_loss = tm.ai_addressable_task_share * t_rework[i] + dip_m

                team_gross_val_m = team_payroll_m * adopt_m * gross_task_gain * t_realization[i]
                team_rework_val_m = team_payroll_m * adopt_m * rework_loss * t_realization[i]
                team_net_val_m = team_gross_val_m - team_rework_val_m

                provisioned_seats = hc * min(1.0, adopt_m * 1.15)
                team_license_m = provisioned_seats * t_seat_cost[i] * token_inflation_factor
                team_allocated_overhead_m = shared_overhead_m * (hc / Float64(total_headcount))
                team_total_cost_m = team_license_m + team_allocated_overhead_m

                m_cost += team_license_m
                m_gross_ben += team_gross_val_m
                m_rework_c += team_rework_val_m
                m_net_ben += team_net_val_m

                w_hc = hc / Float64(total_headcount)
                m_weighted_adopt += w_hc * adopt_m
                eff_prod_i = adopt_m * (gross_task_gain - rework_loss)
                m_weighted_eff_prod += w_hc * eff_prod_i

                team_trial_net_benefit[trial, i] += team_net_val_m
                team_trial_cost[trial, i] += team_total_cost_m
                net_hours_per_emp_m = 160.0 * adopt_m * max(0.0, gross_task_gain - rework_loss)
                team_trial_hours_saved_per_emp[trial, i] += net_hours_per_emp_m

                if m == horizon_months
                    team_trial_net_uplift[trial, i] = eff_prod_i * 100.0
                end
            end

            net_cf_m = m_net_ben - m_cost
            prev_cum_cf = cum_cf
            cum_cf += net_cf_m

            if prev_cum_cf < 0.0 && cum_cf >= 0.0 && m > 2
                frac = -prev_cum_cf / max(1e-6, net_cf_m)
                payback_m = Float64(m - 1) + clamp(frac, 0.0, 1.0)
            elseif cum_cf < 0.0
                payback_m = Float64(horizon_months + 1)
            end

            discount_factor = 1.0 / ((1.0 + monthly_discount_rate)^m)
            npv_acc += net_cf_m * discount_factor

            tot_cost += m_cost
            tot_gross_ben += m_gross_ben
            tot_rework_cost += m_rework_c
            tot_net_ben += m_net_ben

            monthly_cum_cashflow[trial, m] = cum_cf
            monthly_net_cashflow[trial, m] = net_cf_m
            monthly_adoption[trial, m] = m_weighted_adopt * 100.0
            monthly_eff_productivity[trial, m] = m_weighted_eff_prod * 100.0
            monthly_cost_runrate[trial, m] = m_cost
            monthly_benefit_runrate[trial, m] = m_net_ben
        end

        trial_npv[trial] = npv_acc
        trial_total_cost[trial] = tot_cost
        trial_total_gross_benefit[trial] = tot_gross_ben
        trial_total_rework_cost[trial] = tot_rework_cost
        trial_total_net_benefit[trial] = tot_net_ben
        trial_roi_pct[trial] = ((tot_net_ben - tot_cost) / max(1.0, tot_cost)) * 100.0
        trial_payback_month[trial] = payback_m
        trial_month36_adoption[trial] = monthly_adoption[trial, horizon_months]
        trial_month36_net_uplift[trial] = monthly_eff_productivity[trial, horizon_months]

        for i in 1:n_teams
            tc = team_trial_cost[trial, i]
            tnb = team_trial_net_benefit[trial, i]
            team_trial_roi[trial, i] = ((tnb - tc) / max(1.0, tc)) * 100.0
            team_trial_hours_saved_per_emp[trial, i] /= Float64(horizon_months)
        end
    end

    months_axis = collect(1:horizon_months)
    roi_hist = build_histogram(trial_roi_pct, 28, -60.0, 260.0)
    npv_k = trial_npv ./ 1000.0
    npv_hist = build_histogram(npv_k, 28, quantile(npv_k, 0.01), quantile(npv_k, 0.99))

    sensitivities = [
        compute_driver_sensitivity("Turning Saved Time into Profit", "Business Impact", driver_realization, trial_roi_pct, trial_npv),
        compute_driver_sensitivity("Raw Time Saved per Task (%)", "Speed Gain", driver_gross_uplift, trial_roi_pct, trial_npv),
        compute_driver_sensitivity("How Fast Staff Adopt AI", "Rollout Speed", driver_rollout_speed, trial_roi_pct, trial_npv),
        compute_driver_sensitivity("Cleanup & Fact-Checking Time", "Quality Check", driver_rework_drag, trial_roi_pct, trial_npv),
        compute_driver_sensitivity("Monthly Seat & Usage Bill Creep", "Ongoing Cost", driver_token_cost_drift, trial_roi_pct, trial_npv),
        compute_driver_sensitivity("Upfront IT Setup & Training Cost", "Starting Cost", driver_platform_cost, trial_roi_pct, trial_npv)
    ]
    sort!(sensitivities, by = x -> abs(x["npv_swing_usd"]), rev=true)

    team_summaries = Vector{Dict{String, Any}}(undef, n_teams)
    for i in 1:n_teams
        tm = config.teams[i]
        t_roi_vec = view(team_trial_roi, :, i)
        t_nb_vec = view(team_trial_net_benefit, :, i)
        t_cost_vec = view(team_trial_cost, :, i)
        t_up_vec = view(team_trial_net_uplift, :, i)
        t_hrs_vec = view(team_trial_hours_saved_per_emp, :, i)

        team_summaries[i] = Dict{String, Any}(
            "id" => tm.id,
            "name" => tm.name,
            "headcount" => tm.headcount,
            "fully_loaded_annual_cost_usd" => tm.fully_loaded_annual_cost_usd,
            "ai_addressable_task_share_pct" => round(tm.ai_addressable_task_share * 100.0, digits=1),
            "roi_pct" => quantile_summary(t_roi_vec, digits=1),
            "net_benefit_36m_usd" => quantile_summary(t_nb_vec, digits=0),
            "total_cost_36m_usd" => quantile_summary(t_cost_vec, digits=0),
            "net_benefit_per_seat_36m_usd" => quantile_summary((t_nb_vec .- t_cost_vec) ./ Float64(tm.headcount), digits=0),
            "cost_per_seat_monthly_usd" => quantile_summary(t_cost_vec ./ (Float64(tm.headcount) * Float64(horizon_months)), digits=1),
            "month36_net_productivity_uplift_pct" => quantile_summary(t_up_vec, digits=2),
            "avg_monthly_hours_saved_per_fte" => quantile_summary(t_hrs_vec, digits=1),
            "prob_positive_roi_pct" => round(mean(t_roi_vec .> 0.0) * 100.0, digits=1)
        )
    end

    achieved_mask = trial_payback_month .<= Float64(horizon_months)
    prob_breakeven_36m = round(mean(achieved_mask) * 100.0, digits=1)
    prob_breakeven_24m = round(mean(trial_payback_month .<= 24.0) * 100.0, digits=1)
    prob_positive_npv = round(mean(trial_npv .> 0.0) * 100.0, digits=1)

    return Dict{String, Any}(
        "id" => config.id,
        "name" => config.name,
        "tagline" => config.tagline,
        "description" => config.description,
        "board_recommendation" => config.board_recommendation,
        "metadata" => Dict{String, Any}(
            "n_trials" => n_trials,
            "horizon_months" => horizon_months,
            "total_headcount" => total_headcount,
            "total_annual_payroll_usd" => round(total_annual_payroll, digits=0),
            "annual_discount_rate_pct" => round(config.costs.annual_discount_rate * 100.0, digits=1),
            "seed" => seed
        ),
        "assumptions" => Dict{String, Any}(
            "rollout_ceiling_pct" => [round(config.rollout.ceiling_min*100, digits=0), round(config.rollout.ceiling_mode*100, digits=0), round(config.rollout.ceiling_max*100, digits=0)],
            "inflection_month" => [config.rollout.inflection_month_min, config.rollout.inflection_month_mode, config.rollout.inflection_month_max],
            "j_curve_dip_pct" => [round(config.rollout.dip_depth_min*100, digits=1), round(config.rollout.dip_depth_mode*100, digits=1), round(config.rollout.dip_depth_max*100, digits=1)],
            "upfront_platform_p10_p90_usd" => [config.costs.upfront_platform_p10_usd, config.costs.upfront_platform_p90_usd],
            "training_per_seat_usd" => [config.costs.training_per_seat_min_usd, config.costs.training_per_seat_mode_usd, config.costs.training_per_seat_max_usd],
            "annual_token_drift_pct" => [round(config.costs.token_drift_annual_min*100, digits=0), round(config.costs.token_drift_annual_mode*100, digits=0), round(config.costs.token_drift_annual_max*100, digits=0)]
        ),
        "kpis" => Dict{String, Any}(
            "roi_pct" => quantile_summary(trial_roi_pct, digits=1),
            "npv_usd" => quantile_summary(trial_npv, digits=0),
            "payback_months" => quantile_summary(trial_payback_month, digits=1),
            "total_cost_36m_usd" => quantile_summary(trial_total_cost, digits=0),
            "total_gross_benefit_36m_usd" => quantile_summary(trial_total_gross_benefit, digits=0),
            "total_rework_drag_36m_usd" => quantile_summary(trial_total_rework_cost, digits=0),
            "total_net_benefit_36m_usd" => quantile_summary(trial_total_net_benefit, digits=0),
            "month36_adoption_pct" => quantile_summary(trial_month36_adoption, digits=1),
            "month36_net_productivity_uplift_pct" => quantile_summary(trial_month36_net_uplift, digits=2),
            "prob_positive_npv_pct" => prob_positive_npv,
            "prob_breakeven_within_24m_pct" => prob_breakeven_24m,
            "prob_breakeven_within_36m_pct" => prob_breakeven_36m
        ),
        "trajectories" => Dict{String, Any}(
            "months" => months_axis,
            "cumulative_cashflow_usd" => matrix_quantiles(monthly_cum_cashflow, digits=0),
            "monthly_net_cashflow_usd" => matrix_quantiles(monthly_net_cashflow, digits=0),
            "adoption_pct" => matrix_quantiles(monthly_adoption, digits=1),
            "effective_productivity_uplift_pct" => matrix_quantiles(monthly_eff_productivity, digits=2),
            "monthly_cost_usd" => matrix_quantiles(monthly_cost_runrate, digits=0),
            "monthly_benefit_usd" => matrix_quantiles(monthly_benefit_runrate, digits=0)
        ),
        "distributions" => Dict{String, Any}(
            "roi_pct_histogram" => roi_hist,
            "npv_k_usd_histogram" => npv_hist
        ),
        "sensitivity" => sensitivities,
        "teams" => team_summaries
    )
end

