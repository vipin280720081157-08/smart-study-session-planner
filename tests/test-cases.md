# Test Cases: Smart Study Session Planner

This document specifies the validation suites, algorithmic invariants, and operational test cases for the Smart Study Session Planner. Each test can be verified using the built-in automated test suite (`Rscript R/main.R --test`) or interactively through the web interface.

---

## 1. Test Summary Matrix

| ID | Test Case Name | Objective / Invariant | Input Scenario | Expected Outcome | Verification Status |
|---|---|---|---|---|---|
| **TC-01** | Valid Subject Input & Plan Generation | Verify standard multi-subject study plan creation | 5 subjects with upcoming exam dates (6 to 22 days away), 4.0h daily limit | Plan generated with 100% success; valid JSON with summary, prioritized subjects, and timetable | **PASS** |
| **TC-02** | Priority Ordering & Scoring | Ensure subjects are ranked by urgency, difficulty, and demand | Hard subject in 6 days vs. Easy subject in 22 days | Urgent Hard subject ranked #1 (Score > 80); Easy extended subject ranked #5 (Score < 30) | **PASS** |
| **TC-03** | Exam-Date Calculation & Elapsed Days | Validate exact calendar day difference in R | Start date: `2026-10-14`, Exam date: `2026-10-20` | `days_remaining` strictly equals 6 days | **PASS** |
| **TC-04** | Daily Hour Limit Invariant | Invariant: No day's total scheduled study exceeds user limit | 4.0 hours daily limit configured | $\forall d \in \text{Timetable}, \text{scheduled\_hours}(d) \le 4.0$ | **PASS** (0 violations) |
| **TC-05** | Strict Exam Boundary Invariant | Invariant: Never schedule a subject on or after its exam date | Exam date: `2026-10-20` | Zero sessions for this subject on or after `2026-10-20` | **PASS** (0 violations) |
| **TC-06** | Insufficient Preparation Time Detection | Accurately detect and flag study time deficit | 12 hours needed in 2 days with 2.0h/day limit (Max capacity: 4.0h) | Unscheduled hours = 8.0h; Status: "Time Deficit (8.0h Unscheduled)" | **PASS** |
| **TC-07** | Past Exam Date Validation | Reject exams scheduled on or before planning start date | Exam date: Yesterday or Today | HTTP 400 / Error message: "Exam date must be strictly after the planning start date" | **PASS** |
| **TC-08** | Duplicate Subject Detection | Enforce unique subject names (case-insensitive) | Subjects: "Calculus" and "calculus" | Error message: "Duplicate subject detected: 'calculus'. Each subject must have a unique name." | **PASS** |
| **TC-09** | Empty Subject List Handling | Handle empty subject list gracefully | Subjects collection: `[]` | Error message: "At least one subject is required to generate a study timetable." | **PASS** |
| **TC-10** | Timetable Regeneration on Input Change | Ensure timetable recalculates dynamically | User changes daily hours from 4.0h to 6.0h or adds new subject | Timetable updates immediately with expanded daily capacity and recalculated session blocks | **PASS** |

---

## 2. Detailed Test Specifications

### TC-01: Valid Subject Input & Plan Generation
- **Function**: `validate_inputs()`, `calculate_priority()`, `generate_timetable()`
- **Input**:
  ```json
  {
    "start_date": "2026-10-14",
    "daily_hours": 4.0,
    "subjects": [
      { "subject": "Operating Systems", "exam_date": "2026-10-20", "difficulty": "Hard", "estimated_hours": 16 },
      { "subject": "Database Systems", "exam_date": "2026-10-24", "difficulty": "Medium", "estimated_hours": 12 },
      { "subject": "Computer Networks", "exam_date": "2026-10-28", "difficulty": "Hard", "estimated_hours": 18 },
      { "subject": "Software Engineering", "exam_date": "2026-11-01", "difficulty": "Medium", "estimated_hours": 10 },
      { "subject": "Web Technologies", "exam_date": "2026-11-05", "difficulty": "Easy", "estimated_hours": 8 }
    ]
  }
  ```
- **Execution**: Run `Rscript R/main.R --demo`
- **Result**:
  - `success = TRUE`
  - 5 subjects prioritized with ranks 1 through 5.
  - Timetable generated for 22 days horizon with balanced study blocks.

### TC-02: Priority Ordering & Scoring Logic
- **Mathematical Invariants**:
  $$\text{Urgency Score} = \max(10, \; \min(100, \; 105 - 5 \times \text{days\_remaining}))$$
  $$\text{Base Score} = (\text{Urgency} \times 0.50) + (\text{Weight} \times 20) + (\min(10, \text{Demand}) \times 2.5)$$
- **Expected Ranks**:
  1. *Operating Systems*: 6 days away, Hard (2.0x), Demand = 2.67h/day $\rightarrow$ Priority Score $\approx 84.2$ (High)
  2. *Computer Networks*: 14 days away, Hard (2.0x), Demand = 1.29h/day $\rightarrow$ Priority Score $\approx 60.7$ (Medium)
  3. *Database Systems*: 10 days away, Medium (1.5x), Demand = 1.20h/day $\rightarrow$ Priority Score $\approx 60.5$ (Medium)
  4. *Software Engineering*: 18 days away, Medium (1.5x), Demand = 0.56h/day $\rightarrow$ Priority Score $\approx 38.9$ (Low)
  5. *Web Technologies*: 22 days away, Easy (1.0x), Demand = 0.36h/day $\rightarrow$ Priority Score $\approx 25.9$ (Low)

### TC-04 & TC-05: Scheduling Boundary & Capacity Invariants
- **Constraint 1 (No post-exam study)**:
  $$\forall s \in \text{Sessions on Day } d, \quad \text{Date}(d) < \text{ExamDate}(s)$$
  *Verified*: On `2026-10-20` (Operating Systems Exam Day), zero hours are allocated to Operating Systems. Active capacity is transferred to later exams.
- **Constraint 2 (No daily overload)**:
  $$\forall d \in \text{Days}, \quad \sum_{s \in \text{Day } d} \text{Hours}(s) \le \text{DailyStudyHours}$$
  *Verified*: Day 1 to Day 15 scheduled hours strictly equal 4.0h (100% capacity), never exceeding 4.0h.

### TC-06: Insufficient Preparation Time Detection
- **Input**: Subject requiring 12.0h with exam in 2 days, daily limit = 2.0h.
- **Available capacity**: $2 \text{ days} \times 2.0\text{h} = 4.0\text{h}$.
- **Result**:
  - Scheduled hours: 4.0h
  - Unscheduled hours: 8.0h
  - Status: `"Time Deficit (8.0h Unscheduled)"`
  - Guidance note generated suggesting increasing daily study hours or syllabus prioritization.

### TC-07, TC-08, TC-09: Input Validation & Edge Cases
- **Past Exam Date**: `exam_date <= start_date` triggers `tryCatch` error:
  `Exam date for '<name>' must be strictly after the planning start date.`
- **Duplicate Names**: Same name in different casing (`Math` vs `math`) triggers:
  `Duplicate subject detected: 'math'. Each subject must have a unique name.`
- **Empty Subject List**: `subjects = []` triggers:
  `At least one subject is required to generate a study timetable.`
- **Invalid Hours**: `estimated_hours <= 0` or `daily_hours <= 0` properly rejected.

---

## 3. How to Execute Automated Verification

Run the test suite directly from the Windows Command Prompt or PowerShell:

```cmd
cd /d C:\Users\DELL\Desktop\r_projects\smart-study-session-planner
"C:\Program Files\R\R-4.6.1\bin\Rscript.exe" R/main.R --test
```

Expected output:
```text
================================================================
           RUNNING UNIT & CONSTRAINT VERIFICATIONS              
================================================================

[PASS] Test A: Sample subjects loaded and processed successfully.
[PASS] Test B: Verified strictly NO sessions scheduled on or after exam dates.
[PASS] Test C: Verified daily hours limit is never exceeded on any day.
[PASS] Test D: Insufficient time detected and reported accurately.
[PASS] Test E: Past exam dates properly rejected.
[PASS] Test F: Duplicate subject names properly rejected.

================================================================
 ALL VERIFICATION CHECKS PASSED PERFECTLY!
================================================================
```
