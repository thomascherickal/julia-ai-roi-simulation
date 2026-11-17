# Canonical 325-Staff Organization & 4 Plain-English Rollout Strategies

const DEFAULT_TEAMS = [
    TeamArchetype(
        "software_eng",
        "Product & Software Engineering",
        120,
        185_000.0,
        0.55,
        0.10, 0.22, 0.36,   # Raw time saved on coding/testing/docs
        0.03, 0.07, 0.14,   # Code review & bug cleanup time
        55.0, 85.0, 145.0,  # Monthly seat + AI usage fee
        0.45, 0.65, 0.85    # Share of saved time turned into business value
    ),
    TeamArchetype(
        "customer_ops",
        "Customer Support & Success",
        90,
        78_000.0,
        0.65,
        0.15, 0.28, 0.42,   # Ticket auto-drafting & quick answers
        0.02, 0.05, 0.11,   # Escalation checking & quality review
        35.0, 60.0, 105.0,  # Monthly seat + ticket assistant cost
        0.60, 0.78, 0.92    # High conversion into faster replies & lower temp hiring
    ),
    TeamArchetype(
        "sales_gtm",
        "Sales, Account Teams & Marketing",
        75,
        142_000.0,
        0.42,
        0.08, 0.16, 0.28,   # Proposal drafting, account research, campaign copy
        0.02, 0.06, 0.13,   # Brand/accuracy checks
        45.0, 75.0, 120.0,  # Monthly sales AI seat cost
        0.35, 0.55, 0.75    # Moderate conversion (closing deals takes time)
    ),
    TeamArchetype(
        "legal_finance",
        "Legal, Finance & Compliance",
        40,
        165_000.0,
        0.48,
        0.07, 0.15, 0.26,   # Contract review, budget checks, audit prep
        0.04, 0.09, 0.17,   # Careful human fact-checking & sign-off
        60.0, 95.0, 160.0,  # Specialized legal/finance AI seats
        0.40, 0.60, 0.80    # Outside legal & audit fee savings
    )
]

const DEFAULT_SCENARIOS = [
    ScenarioConfig(
        "pragmatic_phased",
        "Step-by-Step Phased Rollout",
        "Train teams first, expand seats in stages, and keep usage bills in check",
        "Covers 325 employees across 4 departments. Teams get hands-on coaching before licenses scale up, preventing runaway usage bills and steadily turning saved hours into real output.",
        "Recommended Baseline Plan: Present the Cautious (P10) to Best-Case (P90) range to the Board, with next-stage funding tied to 6-month adoption and quality checks.",
        RolloutProfile(
            0.70, 0.84, 0.94,
            6.5,  9.5,  14.0,
            0.35, 0.52, 0.75,
            0.02, 0.04, 0.08
        ),
        CostDynamics(
            180_000.0, 460_000.0,
            350.0, 650.0, 1100.0,
            0.05, 0.14, 0.28,
            0.18,
            0.10
        ),
        1.00, 1.00, 1.00, 1.00,
        DEFAULT_TEAMS
    ),
    ScenarioConfig(
        "blitzscale_mandate",
        "Fast All-At-Once Push",
        "Buy seats for everyone on Day 1 without redesigning daily workflows",
        "Gives every employee an AI seat right away with minimal training. Usage jumps early, but lack of guardrails leads to extra cleanup work, frustrated quitters, and climbing monthly usage bills.",
        "Warning / Stress-Test Case: Shows why buying licenses for everyone on Day 1 without training creates wide risk and can lose money in the Cautious (P10) case.",
        RolloutProfile(
            0.75, 0.88, 0.96,
            3.0,  5.0,  8.5,
            0.55, 0.80, 1.15,
            0.05, 0.09, 0.15
        ),
        CostDynamics(
            240_000.0, 680_000.0,
            150.0, 300.0, 550.0,
            0.18, 0.35, 0.60,
            0.22,
            0.10
        ),
        1.05, 1.45, 0.82, 1.25,
        DEFAULT_TEAMS
    ),
    ScenarioConfig(
        "conservative_pilot",
        "Cautious Safety-First Pilot",
        "Strict quality rules, slower rollout, and tight budget caps",
        "Puts safety and cost control first. Teams adopt gradually with thorough human review at every step. Downside risk is very small, though big profits take longer to arrive.",
        "Downside-Protected Plan: Best for regulated teams where avoiding mistakes and protecting the budget matter more than fast payback.",
        RolloutProfile(
            0.50, 0.68, 0.82,
            10.0, 14.0, 19.0,
            0.25, 0.38, 0.55,
            0.01, 0.02, 0.05
        ),
        CostDynamics(
            210_000.0, 520_000.0,
            450.0, 800.0, 1300.0,
            0.02, 0.08, 0.16,
            0.16,
            0.10
        ),
        0.88, 0.78, 0.95, 0.90,
        DEFAULT_TEAMS
    ),
    ScenarioConfig(
        "agentic_transformation",
        "Full Workflow Redesign",
        "Higher upfront investment in training and workflows for bigger Year 2–3 gains",
        "Invests upfront to rethink how teams work from start to finish rather than just bolting chat tools onto old habits. Costs more in Year 1, but delivers the highest 3-year return.",
        "High-Upside Growth Plan: Shows how pairing AI tools with workflow redesign and strong coaching shifts your entire 3-year return higher.",
        RolloutProfile(
            0.78, 0.90, 0.97,
            7.5,  10.5, 14.5,
            0.40, 0.60, 0.85,
            0.03, 0.06, 0.10
        ),
        CostDynamics(
            320_000.0, 780_000.0,
            650.0, 1100.0, 1650.0,
            0.10, 0.22, 0.38,
            0.20,
            0.10
        ),
        1.28, 0.82, 1.18, 1.15,
        DEFAULT_TEAMS
    )
]
