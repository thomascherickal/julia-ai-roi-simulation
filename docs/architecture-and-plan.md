# Executive Plan: 5 Plain-English Ways to Forecast Your AI Rollout

## 1. Why One Spreadsheet Number Is Never Enough

When a Board of Directors asks, *"What will we really get back from our AI investment?"*, a single optimistic spreadsheet number hides the real risks. Different parts of your business affect AI returns in different ways—so we look at the exact same **325-employee rollout** through **five simple lenses**:

| Tab | Plain-English Name (Method) | How It Works | What It Catches That Spreadsheets Miss | Best Used For |
| :--- | :--- | :--- | :--- | :--- |
| **Tab 1** | **10,000 What-If Futures** (`Monte Carlo`) | Tests 10,000 realistic combinations of rollout speed, time saved, and costs | Gives honest **Cautious (`P10`)**, **Typical (`P50`)**, and **Best-Case (`P90`)** profit ranges | Setting budgets, checking downside risk, and estimating breakeven speed |
| **Tab 2** | **Team Behavior** (`Agent-Based`) | Follows 325 individual coworkers sharing tips or quitting when frustrated | Shows how **AI Champions** build momentum while bad rollouts create **unused "shelfware" seats** | Rolling out AI assistants across engineering, support, and sales teams |
| **Tab 3** | **Flywheels & Brakes** (`System Dynamics`) | Tracks multi-year **Growth Flywheels** (team know-how) against **Hidden Brakes** (cleanup work & rising bills) | Shows whether growing company skill outpaces sloppy AI cleanup work and bill creep | 3-year planning, training budgets, and cloud cost guardrails |
| **Tab 4** | **Workflow Waiting Lines** (`Discrete Event`) | Follows everyday work items (tickets, contracts, code) from draft to human sign-off | Pinpoints where **final human reviewers get backed up** when first drafts speed up | Customer support desks, software reviews, sales bids, and legal contracts |
| **Tab 5** | **Pilot Scorecard** (`Bayesian Network`) | Updates your 3-year profit odds as soon as **6-month pilot results** come in | Turns early pilot numbers into a clear **Green Light**, **Fix First**, or **Pause** funding call | Stage-gate Board funding and 6-month pilot reviews |

---

## 2. The 4 Rollout Strategies Tested Across All 5 Tabs

Every tab models the same **325 full-time staff** across four departments (**Product & Software Engineering**, **Customer Support**, **Sales & Marketing**, and **Legal & Finance**) over **36 months**:

1. **Step-by-Step Phased Rollout** (`pragmatic_phased`) — Train teams first, add seats in stages, and keep monthly usage bills under control.
2. **Fast All-At-Once Push** (`blitzscale_mandate`) — Buy seats for everyone on Day 1 without changing workflows—leading to extra cleanup work, frustrated quitters, and review bottlenecks.
3. **Cautious Safety-First Pilot** (`conservative_pilot`) — Strict quality rules, slower adoption, and tight budget caps.
4. **Full Workflow Redesign** (`agentic_transformation`) — Invest more upfront in training and better workflows to unlock the biggest Year 2 and Year 3 gains.

---

## 3. Clean Folder Organization

```text
julia-ai-roi-simulation/
├── Project.toml
├── readme.md                             # Plain-English Executive Overview & Quickstart
├── docs/
│   ├── architecture-and-plan.md          # This plain-English plan & folder map
│   └── methodology-comparison.md         # Side-by-side executive guide & 60-word glossary
├── src/
│   ├── AIROISimulator.jl                 # Main coordinator combining all 5 models
│   ├── core/                             # Shared team numbers, rollout strategies, & JSON export
│   └── simulations/
│       ├── monte-carlo/                  # Tab 1: 10,000 What-If Futures + explanations.md
│       ├── agent-based/                  # Tab 2: Team Behavior Simulation + explanations.md
│       ├── system-dynamics/              # Tab 3: Flywheels & Brakes + explanations.md
│       ├── discrete-event/               # Tab 4: Workflow Waiting Lines + explanations.md
│       └── bayesian-network/             # Tab 5: Pilot Scorecard Updater + explanations.md
├── scripts/
│   └── generate_scenarios.jl             # Precomputes all 5 models into web/data/*.json
├── test/
│   └── runtests.jl                       # 409 automated checks verifying every calculation
└── web/
    ├── index.html                        # 5-Tab Plain-English Explorer with Gold Tooltips
    ├── lab.html                          # Interactive What-If Sliders Page
    ├── tooltips.js                       # <= 60-word plain-English tooltips for every term
    ├── styles.css                        # Light-gold underlines & responsive layout
    ├── app.js                            # 5-tab charts & tables controller
    └── lab.js                            # Live calculator for the What-If Sliders page
```
