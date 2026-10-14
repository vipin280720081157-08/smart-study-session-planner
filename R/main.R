# ==============================================================================
# R/main.R
# Smart Study Session Planner
# Application Startup, CLI Demo/Testing, and Plumber API Service
# ==============================================================================

# 1. Determine Project Root Directory
find_project_root <- function() {
  candidates <- c(
    getwd(),
    file.path(getwd(), "smart-study-session-planner"),
    "C:/Users/DELL/Desktop/r_projects/smart-study-session-planner"
  )
  for (dir in candidates) {
    if (file.exists(file.path(dir, "R", "functions.R"))) {
      return(normalizePath(dir, winslash = "/"))
    }
  }
  return(normalizePath(getwd(), winslash = "/"))
}

project_root <- find_project_root()
setwd(project_root)

# 2. Source Reusable Functions
source(file.path(project_root, "R", "functions.R"))

# 3. CLI Demonstration Runner
run_cli_demo <- function() {
  cat("\n================================================================\n")
  cat("           SMART STUDY SESSION PLANNER (R 4.6.1)                \n")
  cat("               Automated Command-Line Demonstration             \n")
  cat("================================================================\n\n")

  sample_path <- file.path(project_root, "data", "sample_subjects.csv")
  start_date <- format(Sys.Date(), "%Y-%m-%d")
  daily_hours <- 4.0

  cat(sprintf("[1/4] Loading sample subjects from: %s\n", sample_path))
  subjects <- load_sample_subjects(sample_path, start_date = start_date)
  cat(sprintf("      Loaded %d sample subjects.\n", length(subjects)))
  cat(sprintf("      Planning Start Date : %s\n", start_date))
  cat(sprintf("      Daily Study Hours   : %.1f hrs/day\n\n", daily_hours))

  cat("[2/4] Validating inputs & computing transparent priority scores...\n")
  payload <- list(
    start_date = start_date,
    daily_hours = daily_hours,
    subjects = subjects
  )

  plan <- generate_study_plan(payload)
  if (!isTRUE(plan$success)) {
    cat(sprintf("[ERROR] Plan generation failed: %s\n", plan$error))
    return(invisible(NULL))
  }

  cat("\n----------------------------------------------------------------\n")
  cat(" SUBJECT PRIORITY RANKING & WORKLOAD DEMAND\n")
  cat("----------------------------------------------------------------\n")
  for (s in plan$subjects) {
    cat(sprintf("Rank #%d | %-22s | Exam: %s (%2d days left) | Diff: %-6s\n",
                s$rank, s$subject, s$exam_date, s$days_remaining, s$difficulty))
    cat(sprintf("         Priority Score: %5.1f/100 (%s) | Needed: %4.1fh (Demand: %.2fh/day)\n",
                s$priority_score, s$priority_tier, s$estimated_hours, s$daily_demand))
    cat(sprintf("         Reason: %s\n\n", s$priority_reason))
  }

  cat("[3/4] Generating daily timetable & feasibility audit...\n")
  cat("\n----------------------------------------------------------------\n")
  cat(" PLANNING SUMMARY & FEASIBILITY VERDICT\n")
  cat("----------------------------------------------------------------\n")
  cat(sprintf(" Total Planning Horizon : %d calendar days (%s to %s)\n",
              plan$summary$total_planning_days, plan$summary$start_date, plan$summary$horizon_end_date))
  cat(sprintf(" Active Study Days      : %d days\n", plan$summary$active_study_days))
  cat(sprintf(" Required Study Hours   : %.1f hrs\n", plan$summary$total_required_hours))
  cat(sprintf(" Scheduled Study Hours  : %.1f hrs (%.1f%% scheduled)\n",
              plan$summary$total_scheduled_hours, plan$summary$overall_completion_rate))
  cat(sprintf(" Unscheduled Hours      : %.1f hrs\n", plan$summary$total_unscheduled_hours))
  cat(sprintf(" Feasibility Verdict    : %s\n", plan$summary$feasibility_verdict))

  cat("\n----------------------------------------------------------------\n")
  cat(" FIRST 7 DAYS TIMETABLE PREVIEW\n")
  cat("----------------------------------------------------------------\n")
  preview_days <- head(plan$timetable, 7)
  for (d in preview_days) {
    cat(sprintf("\nDay %2d [%s, %s] - Scheduled: %.1f / %.1f hrs (%.0f%%)\n",
                d$day_index, d$date, substr(d$day_of_week, 1, 3),
                d$scheduled_hours, d$available_hours, d$utilization_percent))
    if (length(d$exams_today) > 0) {
      cat(sprintf("   ** EXAM TODAY: %s **\n", paste(d$exams_today, collapse = ", ")))
    }
    if (length(d$sessions) == 0) {
      cat("   [No study sessions scheduled / Rest day]\n")
    } else {
      for (sess in d$sessions) {
        cat(sprintf("   - %-20s : %.1fh | Focus: %s\n",
                    sess$subject, sess$hours, sess$session_focus))
      }
    }
  }

  cat("\n================================================================\n")
  cat(" [SUCCESS] Demonstration completed successfully!\n")
  cat("================================================================\n\n")
}

# 4. CLI Test Runner
run_cli_tests <- function() {
  cat("\n================================================================\n")
  cat("           RUNNING UNIT & CONSTRAINT VERIFICATIONS              \n")
  cat("================================================================\n\n")

  # Test A: Base Sample Execution
  sample_path <- file.path(project_root, "data", "sample_subjects.csv")
  subjs <- load_sample_subjects(sample_path, start_date = Sys.Date())
  res <- generate_study_plan(list(start_date = format(Sys.Date()), daily_hours = 4.0, subjects = subjs))
  stopifnot(isTRUE(res$success))
  cat("[PASS] Test A: Sample subjects loaded and processed successfully.\n")

  # Test B: Strict Constraint - No sessions on or after exam date
  exam_lookup <- setNames(
    vapply(res$subjects, function(s) s$exam_date, character(1)),
    vapply(res$subjects, function(s) s$subject, character(1))
  )
  for (day in res$timetable) {
    d_dt <- as.Date(day$date)
    for (sess in day$sessions) {
      ex_dt <- as.Date(exam_lookup[[sess$subject]])
      if (d_dt >= ex_dt) {
        stop(sprintf("VIOLATION: Subject '%s' scheduled on or after exam date!", sess$subject))
      }
    }
  }
  cat("[PASS] Test B: Verified strictly NO sessions scheduled on or after exam dates.\n")

  # Test C: Strict Constraint - Daily hours never exceeded
  for (day in res$timetable) {
    if (day$scheduled_hours > day$available_hours + 0.001) {
      stop(sprintf("VIOLATION: Day %s scheduled hours (%.1f) exceeds daily limit (%.1f)!",
                   day$date, day$scheduled_hours, day$available_hours))
    }
  }
  cat("[PASS] Test C: Verified daily hours limit is never exceeded on any day.\n")

  # Test D: Insufficient Preparation Time Detection
  tight_res <- generate_study_plan(list(
    start_date = format(Sys.Date()),
    daily_hours = 2.0,
    subjects = list(
      list(subject = "Advanced Physics", exam_date = format(Sys.Date() + 2), difficulty = "Hard", estimated_hours = 12.0)
    )
  ))
  stopifnot(isTRUE(tight_res$success))
  stopifnot(tight_res$audit[[1]]$unscheduled_hours > 0)
  cat("[PASS] Test D: Insufficient time detected and reported accurately.\n")

  # Test E: Validation of past exam dates
  past_res <- generate_study_plan(list(
    start_date = format(Sys.Date()),
    daily_hours = 4.0,
    subjects = list(
      list(subject = "History", exam_date = format(Sys.Date() - 1), difficulty = "Easy", estimated_hours = 5.0)
    )
  ))
  stopifnot(!isTRUE(past_res$success))
  cat("[PASS] Test E: Past exam dates properly rejected.\n")

  # Test F: Duplicate subject detection
  dup_res <- generate_study_plan(list(
    start_date = format(Sys.Date()),
    daily_hours = 4.0,
    subjects = list(
      list(subject = "Calculus", exam_date = format(Sys.Date() + 4), difficulty = "Easy", estimated_hours = 6.0),
      list(subject = "calculus", exam_date = format(Sys.Date() + 6), difficulty = "Hard", estimated_hours = 10.0)
    )
  ))
  stopifnot(!isTRUE(dup_res$success))
  cat("[PASS] Test F: Duplicate subject names properly rejected.\n")

  cat("\n================================================================\n")
  cat(" ALL VERIFICATION CHECKS PASSED PERFECTLY!\n")
  cat("================================================================\n\n")
}

# 5. Start Plumber HTTP Server
start_server <- function(port = 8000, host = "127.0.0.1") {
  if (!requireNamespace("plumber", quietly = TRUE)) {
    stop("The 'plumber' package is required to start the web backend. Please install it using: install.packages('plumber')")
  }

  pr <- plumber::pr()

  # Cross-Origin Resource Sharing (CORS) Filter
  plumber::pr_filter(pr, "cors", function(req, res) {
    res$setHeader("Access-Control-Allow-Origin", "*")
    res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE")
    res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
    if (req$REQUEST_METHOD == "OPTIONS") {
      res$status <- 200
      return(list())
    }
    plumber::forward()
  })

  # Health Check Endpoint
  plumber::pr_get(pr, "/api/health", function() {
    list(
      status = "ok",
      service = "Smart Study Session Planner API",
      r_version = R.version.string,
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC")
    )
  })

  # Sample Data Endpoint
  plumber::pr_get(pr, "/api/sample", function() {
    sample_path <- file.path(project_root, "data", "sample_subjects.csv")
    subjs <- load_sample_subjects(sample_path, start_date = Sys.Date())
    list(
      success = TRUE,
      start_date = format(Sys.Date(), "%Y-%m-%d"),
      daily_hours = 4.0,
      subjects = subjs
    )
  })

  # Study Plan Generation Endpoint
  plumber::pr_post(pr, "/api/plan", function(req, res) {
    payload <- req$body
    # Fallback to parsing postBody if req$body is not parsed
    if (is.null(payload) || length(payload) == 0) {
      if (!is.null(req$postBody) && nchar(req$postBody) > 0) {
        payload <- tryCatch(jsonlite::fromJSON(req$postBody, simplifyVector = FALSE), error = function(e) list())
      }
    }
    generate_study_plan(payload)
  })

  # Mount static web directory
  web_dir <- file.path(project_root, "web")
  if (dir.exists(web_dir)) {
    plumber::pr_static(pr, "/", web_dir)
  }

  cat("\n================================================================\n")
  cat("         SMART STUDY SESSION PLANNER - R BACKEND SERVICE        \n")
  cat("================================================================\n")
  cat(sprintf("  Application URL : http://%s:%d\n", host, port))
  cat(sprintf("  Health Check    : http://%s:%d/api/health\n", host, port))
  cat(sprintf("  Sample Data API : http://%s:%d/api/sample\n", host, port))
  cat(sprintf("  Plan Generator  : http://%s:%d/api/plan\n", host, port))
  cat(sprintf("  Static Directory: %s\n", web_dir))
  cat("================================================================\n")
  cat("  -> Open http://127.0.0.1:8000 in your browser to use the app.\n")
  cat("  -> Press Ctrl+C in this terminal window to stop the service.\n")
  cat("================================================================\n\n")

  plumber::pr_run(pr, port = port, host = host)
}

# 6. Main Execution Router
args <- commandArgs(trailingOnly = TRUE)

if ("--demo" %in% args) {
  run_cli_demo()
} else if ("--test" %in% args) {
  run_cli_tests()
} else {
  # Default action: start the Plumber API server
  port <- 8000
  port_arg <- grep("^--port=", args, value = TRUE)
  if (length(port_arg) > 0) {
    port <- as.integer(sub("^--port=", "", port_arg[1]))
  }
  start_server(port = port, host = "127.0.0.1")
}
