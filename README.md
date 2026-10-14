# Smart Study Session Planner

> A deterministic, rule-based study timetable generator and exam priority planner powered by R. Computes exam urgency, difficulty multipliers, and workload demands to generate realistic daily study sessions.

---

## 1. Project Overview

**Smart Study Session Planner** is a productivity web application designed to help learners systematically organize their preparation for upcoming exams. Rather than relying on arbitrary cramming or complex machine-learning black boxes, the application uses clear, explainable mathematical formulas and rule-based scheduling algorithms implemented in base R.

Users enter their subjects, upcoming exam dates, difficulty levels, estimated preparation hours, planning start date, and daily study limits. The R backend processes these parameters, evaluates exam urgency vectors, calculates transparent priority rankings, and builds a balanced, day-by-day timetable that strictly honors real-world operational constraints.

---

## 2. Key Features

- **Dynamic Subject Management**: Add, edit, and remove exam subjects with immediate client-side and server-side validation.
- **Transparent Priority Scoring**: Ranks subjects using a deterministic multi-factor model (50% Exam Urgency, 20% Difficulty Multiplier, 30% Daily Workload Demand).
- **Explainable Ranking Justifications**: Every subject displays a clear textual justification explaining why it was assigned its specific priority rank.
- **Strict Exam Boundary Enforcement**: Guarantees that no study sessions for a subject are ever scheduled on or after its exam date.
- **Daily Capacity Protection**: Ensures that total study hours allocated on any single day never exceed the user's available study limit.
- **Deficit Detection & Feasibility Audit**: Detects insufficient preparation time when calendar days before an exam are inadequate, highlighting unscheduled hours and offering actionable recommendations.
- **Balanced Multi-Pass Allocation**: Distributes sessions in realistic 1.0 to 2.0-hour focus blocks across active subjects to prevent fatigue.
- **Pedagogical Session Classification**: Tags each allocated session with progressive study objectives (Foundational Concepts $\rightarrow$ Problem Solving $\rightarrow$ High-Yield Review $\rightarrow$ Mock Exam Practice).
- **Lightweight R-Backed Architecture**: Operates locally using a lightweight `plumber` HTTP API serving both the analytical endpoints and static web interface.

---

## 3. R Concepts & Techniques Used

- **Data Frame Manipulation**: Storing, filtering, sorting, and transforming subject inventories using base R data frames (`data.frame`, `order`, `subset`).
- **Date Arithmetic & Temporal Processing**: Using base R `as.Date`, `seq.Date`, and `weekdays` to compute elapsed calendar days, horizon windows, and schedule offsets.
- **Deterministic Mathematical Modeling**: Scaling and bounding multi-criteria score functions using `pmax`, `pmin`, and linear penalty factors.
- **Functional Programming**: Applying `vapply`, `lapply`, and `setNames` for type-safe vector processing and clean data transformation.
- **Defensive Programming & Validation**: Implementing `tryCatch` blocks to catch and reject invalid dates, past exams, negative hours, and duplicate entries.
- **RESTful API Service**: Exposing analytical capabilities via `plumber` endpoints (`/api/health`, `/api/sample`, `/api/plan`) with JSON serialization via `jsonlite`.

---

## 4. Priority Calculation Methodology

The priority score ($0 \le \text{Score} \le 100$) determines the urgency order for allocating daily study sessions. It is calculated using three transparent components:

### 1. Exam Urgency Component (50% Weight)
Closer exams require immediate attention. The urgency score scales linearly with calendar days remaining until the exam:
$$\text{Days Remaining} = \text{as.Date}(\text{Exam Date}) - \text{as.Date}(\text{Start Date})$$
$$\text{Urgency Score} = \max\left(10, \; \min\left(100, \; 105 - (5 \times \text{Days Remaining})\right)\right)$$
- An exam in 1 day scores $100$ (Critical Urgency).
- An exam in 6 days scores $75$ (High Urgency).
- An exam in 14 days scores $35$ (Moderate Urgency).
- Exams $\ge 19$ days away receive a baseline score of $10$.

### 2. Difficulty Multiplier (20% Weight)
More challenging material requires deeper cognitive engagement and repetition:
- **Easy**: Multiplier = $1.0\times$ (Contributes 20 points)
- **Medium**: Multiplier = $1.5\times$ (Contributes 30 points)
- **Hard**: Multiplier = $2.0\times$ (Contributes 40 points)

### 3. Workload Demand Component (30% Weight)
Measures the average study intensity required per eligible day:
$$\text{Daily Demand} = \frac{\text{Estimated Preparation Hours}}{\text{Days Remaining}}$$
$$\text{Demand Points} = \min(10, \; \text{Daily Demand} \times 2.5)$$

### Composite Score Formula
$$\text{Priority Score} = (\text{Urgency Score} \times 0.50) + (\text{Difficulty Multiplier} \times 20) + \text{Demand Points}$$

Scores are categorized into priority tiers:
- **High Priority**: Score $\ge 70$
- **Medium Priority**: $45 \le \text{Score} < 70$
- **Low Priority**: $\text{Score} < 45$

---

## 5. Timetable Allocation Approach

The scheduling algorithm operates day-by-day across the planning horizon ($[\text{Start Date}, \max(\text{Exam Date}) - 1]$):

1. **Daily Capacity Tracking**: Each calendar day starts with an available capacity equal to the user's `daily_study_hours` limit.
2. **Eligible Candidates Filter**: On day $d$, a subject is eligible if and only if:
   - $\text{Current Date}(d) < \text{Exam Date}$ (**Strict Boundary**: Never schedule on or after exam day).
   - $\text{Remaining Preparation Hours} > 0$.
3. **Dynamic Daily Ranking**: Eligible subjects are sorted primarily by exam proximity to the current day ($\text{Exam Date} - \text{Current Date}$), with overall priority score breaking ties.
4. **Multi-Pass Balanced Allocation**:
   - **Pass 1**: Allocates a balanced session block (up to 2.0 hours) to each eligible subject in rank order.
   - **Pass 2**: If daily capacity remains and subjects still have unfulfilled preparation hours, the remaining capacity is allocated to the most urgent subjects until daily hours are filled.
5. **Deficit Audit**: Any preparation hours that could not be scheduled before an exam due to the daily study limit are recorded as `unscheduled_hours`, triggering an explicit deficit notice.

---

## 6. Windows Setup and Run Instructions

### Prerequisites
- **R**: Version 4.0 or later (Tested on **R 4.6.1 ucrt**).
- **Web Browser**: Any modern browser (Chrome, Edge, Firefox).

### 1. Install Essential Dependencies
Open Windows PowerShell or Command Prompt and run:
```cmd
"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" -e "install.packages(c('plumber', 'jsonlite'), repos='https://cloud.r-project.org')"
```

### 2. Start the Application Backend
Navigate to the project directory and start `R/main.R`:
```cmd
cd /d C:\Users\DELL\Desktop\r_projects\smart-study-session-planner
"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" R/main.R
```

The terminal will confirm startup:
```text
================================================================
         SMART STUDY SESSION PLANNER - R BACKEND SERVICE        
================================================================
  Application URL : http://127.0.0.1:8000
  Health Check    : http://127.0.0.1:8000/api/health
  Sample Data API : http://127.0.0.1:8000/api/sample
  Plan Generator  : http://127.0.0.1:8000/api/plan
  Static Directory: C:/Users/DELL/Desktop/r_projects/smart-study-session-planner/web
================================================================
  -> Open http://127.0.0.1:8000 in your browser to use the app.
  -> Press Ctrl+C in this terminal window to stop the service.
================================================================
```

### 3. Access in Local Browser
Open your browser and navigate to:
```
http://127.0.0.1:8000
```
*(Alternatively, you can open `web/index.html` directly in your browser while the R backend is running).*

### 4. Stopping and Restarting
- **To Stop**: In the terminal running the backend, press `Ctrl + C`.
- **To Restart**: Re-run `"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" R/main.R`.

---

## 7. How to Test the Application

### Automated Invariant Verification (CLI)
To run the automated constraint validation suite:
```cmd
cd /d C:\Users\DELL\Desktop\r_projects\smart-study-session-planner
"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" R/main.R --test
```
This executes the automated tests documented in `tests/test-cases.md`, verifying:
- No sessions scheduled on or after exam dates ($0$ violations).
- Daily study hour limits never exceeded ($0$ violations).
- Accurate time deficit detection on compressed schedules.
- Correct rejection of past exam dates and duplicate names.

### Terminal Demonstration (CLI Demo Mode)
To view a text-based timetable generation directly in your terminal:
```cmd
"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" R/main.R --demo
```

---

## 8. Folder Structure

```text
smart-study-session-planner/
├── .gitignore               # Git ignore rules for R session files & OS caches
├── README.md                # Comprehensive project documentation & architecture guide
├── R/
│   ├── functions.R          # Core analytical engine, date logic, scoring & timetable generation
│   └── main.R               # Application entry point, CLI runners, and Plumber HTTP server
├── data/
│   └── sample_subjects.csv  # Realistic sample curriculum data with relative date offsets
├── screenshots/             # Storage for application interface captures
├── tests/
│   └── test-cases.md        # Detailed test matrix, constraints, and validation results
└── web/
    ├── index.html           # Accessible, semantic light-themed dashboard markup
    ├── style.css            # Custom CSS with warm off-white and muted sage-green palette
    └── script.js            # Vanilla JavaScript state manager and R API client
```

---

## 9. Known Limitations & Architecture Notes

1. **R Backend Execution Requirement**:
   All priority calculations, date parsing, and timetable allocations are genuinely executed in R. The web frontend communicates with this R instance via HTTP requests. The frontend cannot generate timetables if the local R backend is not running.
2. **GitHub Pages Limitation**:
   GitHub Pages serves only static web assets (HTML, CSS, JavaScript) and cannot execute an R runtime environment or host a Plumber API server. Consequently, this project is built and optimized for local execution. Attempting to deploy to GitHub Pages without a remote R API hosting provider will leave the interface disconnected from R calculations.
3. **Deterministic Heuristic Model**:
   The generated schedule uses a rule-based multi-pass heuristic. While mathematically balanced and constrained, it does not claim to be a globally optimal mathematical solver (such as integer linear programming). It prioritizes clarity, transparency, and practical feasibility for daily study habits.
