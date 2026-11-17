# AI Adoption Business Case Simulator — Plain-English Executive Edition

**The Problem:** Boards want an AI business case with **honest ranges** (**Cautious `P10`**, **Typical `P50`**, and **Best-Case `P90`**)—not a single optimistic sales number. And no single equation can show financial risk, employee habits, multi-year cost creep, workflow bottlenecks, and 6-month pilot checkpoints all at once.

This project models the exact same **325-employee rollout** across four departments (**Product & Software Engineering**, **Customer Support**, **Sales & Marketing**, and **Legal & Finance**) over **36 months** using **five plain-English forecasting lenses** in **Julia**, published as **Static JSON** via **GitHub Actions**, and explored through a **5-Tab Web App** and an **Interactive What-If Sliders Page**.

> **Light-Gold Underlines, Plain-English Tooltips & In-UI Markdown Guides:** Throughout the web interface ([`web/index.html`](file:///home/thomas/Projects/julia-ai-roi-simulation/web/index.html) and [`web/lab.html`](file:///home/thomas/Projects/julia-ai-roi-simulation/web/lab.html)), every technical term, statistic, and methodology is **underlined in light gold** with an interactive tooltip of **at most 60 words**, and each simulation includes an in-UI **📖 Read Full Plain-English Guide (`explanations.md`)** modal that renders all Markdown elements (headings, tables, blockquotes, task lists, code blocks, and links).

---

## 1. Five Plain-English Lenses on the Same Rollout

| Tab | Plain-English Lens | How It Works | What It Catches for Leaders | Best Used For | Folder & Plain-English Guide |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Tab 1** | **10,000 What-If Futures** *(Monte Carlo)* | Tests 10,000 realistic combinations of rollout speed, time saved, cleanup time, and costs | Honest **Cautious (`P10`)**, **Typical (`P50`)**, and **Best-Case (`P90`)** profit ranges | Board budgets, downside protection, and breakeven speed | [`MonteCarloModel.jl`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/monte-carlo/MonteCarloModel.jl)<br>[`explanations.md`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/monte-carlo/explanations.md) |
| **Tab 2** | **Team Behavior** *(Agent-Based)* | Follows 325 individual coworkers sharing tips or quitting when frustrated | How **AI Champions** build momentum while rushed rollouts create **unused "shelfware" seats** | Rolling out AI assistants to engineering, support, and sales teams | [`AgentBasedModel.jl`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/agent-based/AgentBasedModel.jl)<br>[`explanations.md`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/agent-based/explanations.md) |
| **Tab 3** | **Flywheels & Brakes** *(System Dynamics)* | Tracks multi-year **Growth Flywheels** (team know-how) against **Hidden Brakes** (cleanup work & rising bills) | Whether growing company skill outpaces sloppy AI cleanup work and monthly bill creep | 3-year planning, training budgets, and cloud cost guardrails | [`SystemDynamicsModel.jl`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/system-dynamics/SystemDynamicsModel.jl)<br>[`explanations.md`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/system-dynamics/explanations.md) |
| **Tab 4** | **Workflow Waiting Lines** *(Discrete Event)* | Follows everyday work items (tickets, contracts, code) from first draft to final human review | Where **final human reviewers get backed up** when AI speeds up first drafts | Customer support desks, software reviews, sales proposals, and legal contracts | [`DiscreteEventModel.jl`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/discrete-event/DiscreteEventModel.jl)<br>[`explanations.md`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/discrete-event/explanations.md) |
| **Tab 5** | **Pilot Scorecard** *(Bayesian Network)* | Updates your 3-year profit odds as soon as **6-month pilot results** come in | Turns early pilot numbers into a clear **Green Light**, **Fix First**, or **Hold** funding decision | Stage-gate Board funding and 6-month pilot reviews | [`BayesianNetworkModel.jl`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/bayesian-network/BayesianNetworkModel.jl)<br>[`explanations.md`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/bayesian-network/explanations.md) |

---

## 2. Compare the 4 Rollout Strategies Across All 5 Lenses

| Rollout Strategy | 1. Financial Range (`P10` / `P50` / `P90`) | 2. Team Behavior Return | 3. Flywheels & Brakes Return | 4. Workflow Lines Return | 5. Pilot Scorecard Return | Typical 3-Year Net Profit |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Step-by-Step Phased Rollout** *(Recommended)* | `+59.1%` / **`+139.9%`** / `+235.6%` | **`+214.3%`** | **`+169.5%`** | **`+126.6%`** | **`+126.2%`** | **+\$1.85M** |
| **Fast All-At-Once Push** *(Stress Test)* | `-34.5%` / **`+18.9%`** / `+85.5%` | **`-69.8%`** *(Quitters)* | **`-16.7%`** *(Cleanup)* | **`-16.5%`** *(Review Line)* | **`+65.7%`** | **+\$350k** |
| **Cautious Safety-First Pilot** | `+16.7%` / **`+74.8%`** / `+146.4%` | **`+154.5%`** | **`+110.4%`** | **`+82.6%`** | **`+118.1%`** | **+\$715k** |
| **Full Workflow Redesign** | `+107.4%` / **`+194.6%`** / `+300.7%` | **`+335.9%`** | **`+262.8%`** | **`+187.1%`** | **`+177.2%`** | **+\$3.87M** |

---

## 3. Folder Organization (`julia-ai-roi-simulation/`)

- [`src/AIROISimulator.jl`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/AIROISimulator.jl) & [`src/core/`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/core/scenarios.jl) — Shared rollout strategies, department numbers, and JSON writer.
- [`src/simulations/monte-carlo/`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/monte-carlo/explanations.md) — **Tab 1:** 10,000 What-If Futures model & plain-English guide.
- [`src/simulations/agent-based/`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/agent-based/explanations.md) — **Tab 2:** Team Behavior model & plain-English guide.
- [`src/simulations/system-dynamics/`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/system-dynamics/explanations.md) — **Tab 3:** Flywheels & Brakes model & plain-English guide.
- [`src/simulations/discrete-event/`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/discrete-event/explanations.md) — **Tab 4:** Workflow Waiting Lines model & plain-English guide.
- [`src/simulations/bayesian-network/`](file:///home/thomas/Projects/julia-ai-roi-simulation/src/simulations/bayesian-network/explanations.md) — **Tab 5:** Pilot Scorecard Updater model & plain-English guide.
- [`web/index.html`](file:///home/thomas/Projects/julia-ai-roi-simulation/web/index.html), [`web/lab.html`](file:///home/thomas/Projects/julia-ai-roi-simulation/web/lab.html), [`web/tooltips.js`](file:///home/thomas/Projects/julia-ai-roi-simulation/web/tooltips.js) — 5-Tab Executive Explorer, Interactive What-If Sliders page, in-UI Markdown modal viewer, and light-gold underlined tooltips (`<= 60 words` each).
- [`scripts/serve_web.py`](file:///home/thomas/Projects/julia-ai-roi-simulation/scripts/serve_web.py) — Local web server that automatically closes when the browser window/tab is closed.
- [`docs/architecture-and-plan.md`](file:///home/thomas/Projects/julia-ai-roi-simulation/docs/architecture-and-plan.md) & [`docs/methodology-comparison.md`](file:///home/thomas/Projects/julia-ai-roi-simulation/docs/methodology-comparison.md) — Plain-English executive overview and complete glossary.
- [`test/runtests.jl`](file:///home/thomas/Projects/julia-ai-roi-simulation/test/runtests.jl) — Automated test suite verifying every model, tooltip, button, and JSON export.

---

## 4. Quick Start

```bash
# 1. Run all automated checks and rebuild the precomputed JSON & Markdown files
julia --project=. test/runtests.jl
julia --project=. scripts/generate_scenarios.jl

# 2. Launch the web server (automatically closes when you close the browser tab!)
python3 scripts/serve_web.py --port 8080 --open-browser
```

- **5-Tab Executive Explorer:** `http://localhost:8080/index.html`
- **Interactive What-If Sliders:** `http://localhost:8080/lab.html`
