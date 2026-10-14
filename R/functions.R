# ==============================================================================
# R/functions.R
# Smart Study Session Planner
# Reusable Analytical and Scheduling Engine Functions
# ==============================================================================

#' Validate Inputs for Study Session Planning
#'
#' Validates user-provided subject parameters, planning start date,
#' and daily available study hours. Enforces strict consistency rules:
#' - Start date must be a valid YYYY-MM-DD date.
#' - Daily hours must be numeric between 0.5 and 24.
#' - Subject list must be non-empty.
#' - Subject names must be non-empty and unique (case-insensitive).
#' - Exam dates must be valid and strictly after the planning start date.
#' - Estimated preparation hours must be positive numbers.
#'
#' @param subjects A data.frame or list of subject records.
#' @param start_date Character string or Date representing the planning start date.
#' @param daily_hours Numeric value of available study hours per day.
#' @return A validated data.frame with typed columns.
validate_inputs <- function(subjects, start_date = Sys.Date(), daily_hours = 4) {
  # 1. Validate planning start date
  parsed_start <- tryCatch(as.Date(start_date), error = function(e) NA)
  if (is.na(parsed_start)) {
    stop("Invalid planning start date. Please provide a valid date in YYYY-MM-DD format.")
  }

  # 2. Validate daily study hours
  if (!is.numeric(daily_hours) || is.na(daily_hours) || daily_hours <= 0 || daily_hours > 24) {
    stop("Available daily study hours must be a positive number between 0.5 and 24.0 hours.")
  }

  # 3. Validate subject collection
  if (is.null(subjects)) {
    stop("Subject collection cannot be null. Please provide at least one subject.")
  }

  # Convert list of lists to data.frame if needed
  if (is.list(subjects) && !is.data.frame(subjects)) {
    if (length(subjects) == 0) {
      stop("At least one subject is required to generate a study timetable.")
    }
    df_rows <- lapply(subjects, function(s) {
      data.frame(
        subject = as.character(s$subject %||% s$name %||% ""),
        exam_date = as.character(s$exam_date %||% ""),
        difficulty = as.character(s$difficulty %||% "Medium"),
        estimated_hours = as.numeric(s$estimated_hours %||% 0),
        stringsAsFactors = FALSE
      )
    })
    subjects_df <- do.call(rbind, df_rows)
  } else if (is.data.frame(subjects)) {
    subjects_df <- subjects
    if (nrow(subjects_df) == 0) {
      stop("At least one subject is required to generate a study timetable.")
    }
    # Standardize column names
    col_map <- c("name" = "subject", "Subject" = "subject", "ExamDate" = "exam_date",
                 "Difficulty" = "difficulty", "EstimatedHours" = "estimated_hours")
    for (old_col in names(col_map)) {
      if (old_col %in% names(subjects_df) && !"subject" %in% names(subjects_df)) {
        names(subjects_df)[names(subjects_df) == old_col] <- col_map[[old_col]]
      }
    }
  } else {
    stop("Invalid subjects format. Expected data.frame or list of subject objects.")
  }

  # 4. Check for mandatory columns
  req_cols <- c("subject", "exam_date", "difficulty", "estimated_hours")
  missing_cols <- setdiff(req_cols, names(subjects_df))
  if (length(missing_cols) > 0) {
    stop(sprintf("Subjects data is missing required columns: %s", paste(missing_cols, collapse = ", ")))
  }

  # 5. Row-by-row validation
  cleaned_names <- trimws(as.character(subjects_df$subject))
  if (any(nchar(cleaned_names) == 0)) {
    stop("Subject name cannot be empty. Please ensure every subject has a descriptive name.")
  }

  # Check duplicate names (case-insensitive)
  lower_names <- tolower(cleaned_names)
  dup_indices <- which(duplicated(lower_names))
  if (length(dup_indices) > 0) {
    dup_name <- cleaned_names[dup_indices[1]]
    stop(sprintf("Duplicate subject detected: '%s'. Each subject must have a unique name.", dup_name))
  }

  # Validate exam dates
  parsed_exam_dates <- tryCatch(as.Date(subjects_df$exam_date), error = function(e) rep(as.Date(NA), nrow(subjects_df)))
  if (any(is.na(parsed_exam_dates))) {
    bad_idx <- which(is.na(parsed_exam_dates))[1]
    stop(sprintf("Invalid exam date for subject '%s'. Please use YYYY-MM-DD format.", cleaned_names[bad_idx]))
  }

  # STRICT RULE: Exam date must be strictly after planning start date
  past_or_today <- parsed_exam_dates <= parsed_start
  if (any(past_or_today)) {
    bad_idx <- which(past_or_today)[1]
    stop(sprintf("Exam date for '%s' (%s) must be strictly after the planning start date (%s). Preparation sessions cannot be scheduled on or after the exam date.",
                 cleaned_names[bad_idx], format(parsed_exam_dates[bad_idx]), format(parsed_start)))
  }

  # Validate difficulties
  valid_diffs <- c("Easy", "Medium", "Hard")
  cleaned_diffs <- vapply(as.character(subjects_df$difficulty), function(d) {
    d_clean <- trimws(tolower(d))
    if (d_clean %in% c("easy", "e", "1")) return("Easy")
    if (d_clean %in% c("medium", "med", "m", "2")) return("Medium")
    if (d_clean %in% c("hard", "difficult", "h", "3")) return("Hard")
    return("Medium") # default fallback
  }, character(1))

  # Validate estimated hours
  num_hours <- suppressWarnings(as.numeric(subjects_df$estimated_hours))
  if (any(is.na(num_hours)) || any(num_hours <= 0)) {
    bad_idx <- which(is.na(num_hours) | num_hours <= 0)[1]
    stop(sprintf("Estimated preparation hours for '%s' must be a positive number greater than 0.", cleaned_names[bad_idx]))
  }
  if (any(num_hours > 300)) {
    bad_idx <- which(num_hours > 300)[1]
    stop(sprintf("Estimated preparation hours for '%s' (%.1f hrs) exceeds the realistic single-session planner limit of 300 hours.",
                 cleaned_names[bad_idx], num_hours[bad_idx]))
  }

  # Construct clean, validated data.frame
  data.frame(
    subject = cleaned_names,
    exam_date = parsed_exam_dates,
    difficulty = cleaned_diffs,
    estimated_hours = round(num_hours, 1),
    stringsAsFactors = FALSE
  )
}

# Helper null-coalescing operator
`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0 || is.na(a)) b else a
}

#' Calculate Transparent Priority Scores for Subjects
#'
#' Implements a deterministic, explainable multi-factor scoring model:
#' 1. Exam Urgency (50% weight): Linear scale based on days remaining.
#' 2. Difficulty Multiplier (20% weight): Easy = 1.0, Medium = 1.5, Hard = 2.0.
#' 3. Daily Workload Demand (30% weight): Estimated preparation hours divided by eligible days.
#'
#' @param subjects_df Validated data.frame from validate_inputs.
#' @param start_date Planning start date.
#' @return Data.frame with priority metrics, scores, tiers, ranks, and textual explanations.
calculate_priority <- function(subjects_df, start_date = Sys.Date()) {
  start_dt <- as.Date(start_date)
  n <- nrow(subjects_df)

  # Calculate days remaining (strictly before exam)
  days_remaining <- as.numeric(subjects_df$exam_date - start_dt)
  study_days_available <- pmax(1, days_remaining)

  # Difficulty Weights
  diff_weights <- c("Easy" = 1.0, "Medium" = 1.5, "Hard" = 2.0)
  weights <- unname(diff_weights[subjects_df$difficulty])
  weights[is.na(weights)] <- 1.5

  # Daily Workload Demand (hours needed per day if studied evenly)
  daily_demand <- round(subjects_df$estimated_hours / study_days_available, 2)

  # Urgency Score: 100 for 1 day left, decreasing by 5 per day, floored at 10
  # Formula: clamp(105 - 5 * days_remaining, 10, 100)
  urgency_scores <- pmax(10, pmin(100, 105 - (5 * days_remaining)))

  # Composite Priority Score (0 to 100 scale)
  # 50% Urgency (max 50) + Difficulty component (max 40) + Workload Demand (max 10)
  # Easy=20, Medium=30, Hard=40 from difficulty
  # Demand contribution: capped at 10 points (daily_demand * 2.5, max 10)
  diff_component <- weights * 20 # 20 (Easy), 30 (Medium), 40 (Hard)
  demand_component <- pmin(10, daily_demand * 2.5)
  composite_raw <- (urgency_scores * 0.50) + diff_component + demand_component
  priority_scores <- round(pmax(10, pmin(100, composite_raw)), 1)

  # Priority Tiers
  priority_tiers <- ifelse(priority_scores >= 70, "High Priority",
                    ifelse(priority_scores >= 45, "Medium Priority", "Low Priority"))

  # Understandable textual reasoning for each ranking
  priority_reasons <- vapply(seq_len(n), function(i) {
    urg_text <- if (days_remaining[i] <= 3) "Critical urgency"
                else if (days_remaining[i] <= 7) "High urgency"
                else if (days_remaining[i] <= 14) "Moderate urgency"
                else "Low urgency / extended horizon"

    sprintf("Exam in %d days (%s, %d/100). %s difficulty (%.1fx factor) with %.2f hrs/day workload demand.",
            days_remaining[i], urg_text, round(urgency_scores[i]),
            subjects_df$difficulty[i], weights[i], daily_demand[i])
  }, character(1))

  # Assemble enhanced data.frame
  result_df <- data.frame(
    subject = subjects_df$subject,
    exam_date = subjects_df$exam_date,
    difficulty = subjects_df$difficulty,
    difficulty_weight = weights,
    estimated_hours = subjects_df$estimated_hours,
    days_remaining = days_remaining,
    study_days_available = study_days_available,
    daily_demand = daily_demand,
    urgency_score = round(urgency_scores, 1),
    priority_score = priority_scores,
    priority_tier = priority_tiers,
    priority_reason = priority_reasons,
    stringsAsFactors = FALSE
  )

  # Sort by priority_score descending, break ties with earlier exam_date, then higher estimated_hours
  ord <- order(-result_df$priority_score, result_df$exam_date, -result_df$estimated_hours)
  result_df <- result_df[ord, , drop = FALSE]
  result_df$rank <- seq_len(nrow(result_df))
  rownames(result_df) <- NULL

  return(result_df)
}

#' Generate Realistic Study Timetable Across Available Days
#'
#' Allocates study sessions day-by-day according to strict operational rules:
#' 1. Never schedule a subject on or after its exam date.
#' 2. Never exceed daily available study hours on any day.
#' 3. Distribute preparation sessions across eligible days before each exam.
#' 4. Detect insufficient preparation time and accurately report unscheduled hours.
#' 5. Provide balanced multi-subject blocks per day to maintain focus and prevent fatigue.
#'
#' @param prioritized_df Subject data.frame output by calculate_priority.
#' @param start_date Planning start date (Date or character).
#' @param daily_hours Maximum available study hours per day.
#' @return A list containing the day-by-day timetable and subject audit summaries.
generate_timetable <- function(prioritized_df, start_date = Sys.Date(), daily_hours = 4) {
  start_dt <- as.Date(start_date)
  num_subjects <- nrow(prioritized_df)

  if (num_subjects == 0) {
    return(list(timetable = list(), subject_audit = list(), summary = list()))
  }

  # Planning horizon ends on the day before the latest exam
  max_exam_dt <- max(prioritized_df$exam_date)
  horizon_end_dt <- max_exam_dt - 1

  # Total days in planning window
  total_days <- as.numeric(horizon_end_dt - start_dt) + 1
  if (total_days < 1) total_days <- 1

  all_dates <- seq.Date(from = start_dt, by = "day", length.out = total_days)

  # Track remaining preparation hours needed for each subject
  remaining_hours <- setNames(prioritized_df$estimated_hours, prioritized_df$subject)
  scheduled_hours <- setNames(rep(0, num_subjects), prioritized_df$subject)

  # Daily timetable records
  daily_schedule <- vector("list", total_days)

  # Standard session chunk size: balanced between 1.0 and 2.0 hours
  # If daily_hours <= 2, session chunk is daily_hours. If daily_hours == 4, session chunk is 2.0
  base_chunk_size <- max(0.5, min(2.0, round(daily_hours / 2, 1)))

  for (d_idx in seq_along(all_dates)) {
    curr_date <- all_dates[d_idx]
    day_capacity <- daily_hours
    day_sessions <- list()

    # Find candidate subjects for today:
    # 1. STRICT: curr_date < exam_date (Never schedule on or after exam date)
    # 2. remaining_hours > 0
    candidate_mask <- (prioritized_df$exam_date > curr_date) & (remaining_hours[prioritized_df$subject] > 0)
    candidates <- prioritized_df[candidate_mask, , drop = FALSE]

    if (nrow(candidates) > 0) {
      # Dynamic prioritization for this specific day:
      # Days remaining from current day to exam
      days_to_exam_curr <- as.numeric(candidates$exam_date - curr_date)

      # Sort candidates by:
      # Primary: nearest exam first (days_to_exam_curr)
      # Secondary: overall priority score descending
      cand_order <- order(days_to_exam_curr, -candidates$priority_score)
      sorted_candidates <- candidates[cand_order, , drop = FALSE]

      # Multi-pass allocation to balance subjects across days
      # Pass 1: Give each eligible subject up to base_chunk_size
      for (c_idx in seq_len(nrow(sorted_candidates))) {
        if (day_capacity <= 0.05) break
        subj_name <- sorted_candidates$subject[c_idx]
        needed <- remaining_hours[[subj_name]]
        if (needed <= 0.05) next

        alloc <- min(needed, base_chunk_size, day_capacity)
        alloc <- round(alloc, 1)

        if (alloc >= 0.2) {
          day_capacity <- round(day_capacity - alloc, 1)
          remaining_hours[[subj_name]] <- round(remaining_hours[[subj_name]] - alloc, 1)
          scheduled_hours[[subj_name]] <- round(scheduled_hours[[subj_name]] + alloc, 1)

          day_sessions[[length(day_sessions) + 1]] <- list(
            subject = subj_name,
            hours = alloc,
            difficulty = sorted_candidates$difficulty[c_idx],
            priority_tier = sorted_candidates$priority_tier[c_idx],
            days_to_exam = days_to_exam_curr[c_idx],
            session_focus = determine_session_focus(
              total_hours = sorted_candidates$estimated_hours[c_idx],
              scheduled_so_far = scheduled_hours[[subj_name]]
            )
          )
        }
      }

      # Pass 2: If day capacity remains, allocate additional available time to most urgent candidate
      if (day_capacity >= 0.3) {
        for (c_idx in seq_len(nrow(sorted_candidates))) {
          if (day_capacity <= 0.05) break
          subj_name <- sorted_candidates$subject[c_idx]
          needed <- remaining_hours[[subj_name]]
          if (needed <= 0.05) next

          alloc <- min(needed, day_capacity)
          alloc <- round(alloc, 1)

          if (alloc >= 0.2) {
            day_capacity <- round(day_capacity - alloc, 1)
            remaining_hours[[subj_name]] <- round(remaining_hours[[subj_name]] - alloc, 1)
            scheduled_hours[[subj_name]] <- round(scheduled_hours[[subj_name]] + alloc, 1)

            # Check if this subject already had a session today; if so, combine or add extension
            existing_idx <- which(vapply(day_sessions, function(s) s$subject == subj_name, logical(1)))
            if (length(existing_idx) > 0) {
              day_sessions[[existing_idx[1]]]$hours <- round(day_sessions[[existing_idx[1]]]$hours + alloc, 1)
            } else {
              day_sessions[[length(day_sessions) + 1]] <- list(
                subject = subj_name,
                hours = alloc,
                difficulty = sorted_candidates$difficulty[c_idx],
                priority_tier = sorted_candidates$priority_tier[c_idx],
                days_to_exam = days_to_exam_curr[c_idx],
                session_focus = determine_session_focus(
                  total_hours = sorted_candidates$estimated_hours[c_idx],
                  scheduled_so_far = scheduled_hours[[subj_name]]
                )
              )
            }
          }
        }
      }
    }

    # Record day entry
    scheduled_today <- round(daily_hours - day_capacity, 1)
    day_name <- weekdays(curr_date, abbreviate = FALSE)
    date_str <- format(curr_date, "%Y-%m-%d")

    # Check which exams occur on this day
    exams_today <- prioritized_df$subject[prioritized_df$exam_date == curr_date]

    daily_schedule[[d_idx]] <- list(
      date = date_str,
      day_index = d_idx,
      day_of_week = day_name,
      available_hours = daily_hours,
      scheduled_hours = scheduled_today,
      free_hours = round(day_capacity, 1),
      utilization_percent = round((scheduled_today / daily_hours) * 100, 1),
      sessions = day_sessions,
      exams_today = exams_today,
      is_rest_day = (scheduled_today == 0)
    )
  }

  # Build Subject Audit and Feasibility Breakdown
  subject_audit <- lapply(seq_len(num_subjects), function(i) {
    subj_name <- prioritized_df$subject[i]
    req_hours <- prioritized_df$estimated_hours[i]
    sched_hrs <- unname(scheduled_hours[[subj_name]])
    unsched_hrs <- round(max(0, req_hours - sched_hrs), 1)
    completion_rate <- round((sched_hrs / req_hours) * 100, 1)

    # Feasibility status & recommendation
    if (unsched_hrs <= 0.05) {
      status <- "Fully Scheduled"
      status_type <- "success"
      feasibility_note <- sprintf("All %.1f hours successfully scheduled before the exam on %s.",
                                  req_hours, format(prioritized_df$exam_date[i]))
    } else {
      status <- sprintf("Time Deficit (%.1fh Unscheduled)", unsched_hrs)
      status_type <- "warning"
      feasibility_note <- sprintf("Insufficient study capacity: %.1fh could not be scheduled before %s due to daily study limit (%.1fh/day). Recommendation: Increase daily hours or prioritize core syllabus topics.",
                                  unsched_hrs, format(prioritized_df$exam_date[i]), daily_hours)
    }

    list(
      subject = subj_name,
      exam_date = format(prioritized_df$exam_date[i], "%Y-%m-%d"),
      days_remaining = prioritized_df$days_remaining[i],
      difficulty = prioritized_df$difficulty[i],
      priority_tier = prioritized_df$priority_tier[i],
      priority_score = prioritized_df$priority_score[i],
      rank = prioritized_df$rank[i],
      required_hours = req_hours,
      scheduled_hours = sched_hrs,
      unscheduled_hours = unsched_hrs,
      completion_rate = completion_rate,
      status = status,
      status_type = status_type,
      feasibility_note = feasibility_note
    )
  })

  # Overall Summary Metrics
  total_required <- sum(prioritized_df$estimated_hours)
  total_scheduled <- sum(vapply(subject_audit, function(s) s$scheduled_hours, numeric(1)))
  total_unscheduled <- round(total_required - total_scheduled, 1)
  overall_completion_rate <- round((total_scheduled / total_required) * 100, 1)

  active_study_days <- sum(vapply(daily_schedule, function(d) d$scheduled_hours > 0, logical(1)))

  summary_metrics <- list(
    total_subjects = num_subjects,
    start_date = format(start_dt, "%Y-%m-%d"),
    horizon_end_date = format(horizon_end_dt, "%Y-%m-%d"),
    total_planning_days = total_days,
    active_study_days = active_study_days,
    daily_available_hours = daily_hours,
    total_required_hours = total_required,
    total_scheduled_hours = total_scheduled,
    total_unscheduled_hours = total_unscheduled,
    overall_completion_rate = overall_completion_rate,
    feasibility_verdict = if (total_unscheduled == 0) "Complete & Feasible" else "Time Deficit Detected"
  )

  list(
    timetable = daily_schedule,
    subject_audit = subject_audit,
    summary = summary_metrics
  )
}

#' Helper to Assign Pedagogical Study Session Focus
#'
#' Classifies session objective based on progress through required hours.
determine_session_focus <- function(total_hours, scheduled_so_far) {
  ratio <- scheduled_so_far / total_hours
  if (ratio <= 0.35) {
    "Foundational Concepts & Core Theory"
  } else if (ratio <= 0.70) {
    "Problem Solving & Analytical Exercises"
  } else if (ratio <= 0.90) {
    "High-Yield Review & Past Paper Problems"
  } else {
    "Final Summary, Formula Sheets & Mock Test"
  }
}

#' Load Sample Subjects from CSV with Relative Date Offsets
#'
#' Reads sample subjects from data/sample_subjects.csv and adjusts exam dates
#' relative to the provided start date so sample data is always valid and testable.
#'
#' @param filepath Path to the sample CSV file.
#' @param start_date Base date to calculate relative exam dates.
#' @return A list of subject records.
load_sample_subjects <- function(filepath = "data/sample_subjects.csv", start_date = Sys.Date()) {
  start_dt <- as.Date(start_date)

  if (!file.exists(filepath)) {
    # Fallback default dataset if CSV not found
    return(list(
      list(subject = "Operating Systems", exam_date = format(start_dt + 6), difficulty = "Hard", estimated_hours = 16),
      list(subject = "Database Systems", exam_date = format(start_dt + 10), difficulty = "Medium", estimated_hours = 12),
      list(subject = "Computer Networks", exam_date = format(start_dt + 14), difficulty = "Hard", estimated_hours = 18),
      list(subject = "Software Engineering", exam_date = format(start_dt + 18), difficulty = "Medium", estimated_hours = 10),
      list(subject = "Web Technologies", exam_date = format(start_dt + 22), difficulty = "Easy", estimated_hours = 8)
    ))
  }

  raw_df <- read.csv(filepath, stringsAsFactors = FALSE, strip.white = TRUE)

  # Check if CSV uses days_offset or explicit exam_date
  if ("days_offset" %in% names(raw_df)) {
    raw_df$exam_date <- format(start_dt + as.integer(raw_df$days_offset), "%Y-%m-%d")
  } else if ("exam_date" %in% names(raw_df)) {
    # If date is in the past, adjust dynamically
    exam_dates <- as.Date(raw_df$exam_date)
    if (any(is.na(exam_dates) | exam_dates <= start_dt)) {
      raw_df$exam_date <- format(start_dt + seq(5, 5 + 4 * (nrow(raw_df) - 1), by = 4), "%Y-%m-%d")
    }
  }

  lapply(seq_len(nrow(raw_df)), function(i) {
    list(
      subject = as.character(raw_df$subject[i]),
      exam_date = as.character(raw_df$exam_date[i]),
      difficulty = as.character(raw_df$difficulty[i]),
      estimated_hours = as.numeric(raw_df$estimated_hours[i])
    )
  })
}

#' Generate Complete Study Plan (Coordinator Function)
#'
#' Accepts raw input payload, validates data, computes priority metrics,
#' runs the timetable allocation algorithm, and packages full JSON-ready output.
#'
#' @param input_payload List containing start_date, daily_hours, and subjects.
#' @return List with success flag, summary, prioritized subjects, timetable, and audit.
generate_study_plan <- function(input_payload) {
  tryCatch({
    start_date <- input_payload$start_date %||% format(Sys.Date(), "%Y-%m-%d")
    daily_hours <- as.numeric(input_payload$daily_hours %||% 4.0)
    subjects_raw <- input_payload$subjects

    # 1. Validation
    validated_df <- validate_inputs(subjects_raw, start_date = start_date, daily_hours = daily_hours)

    # 2. Priority Scoring
    prioritized_df <- calculate_priority(validated_df, start_date = start_date)

    # 3. Timetable Allocation
    schedule_result <- generate_timetable(prioritized_df, start_date = start_date, daily_hours = daily_hours)

    # Convert prioritized_df to list for clean JSON serialization
    subjects_list <- lapply(seq_len(nrow(prioritized_df)), function(i) {
      list(
        rank = prioritized_df$rank[i],
        subject = prioritized_df$subject[i],
        exam_date = format(prioritized_df$exam_date[i], "%Y-%m-%d"),
        difficulty = prioritized_df$difficulty[i],
        difficulty_weight = prioritized_df$difficulty_weight[i],
        estimated_hours = prioritized_df$estimated_hours[i],
        days_remaining = prioritized_df$days_remaining[i],
        study_days_available = prioritized_df$study_days_available[i],
        daily_demand = prioritized_df$daily_demand[i],
        urgency_score = prioritized_df$urgency_score[i],
        priority_score = prioritized_df$priority_score[i],
        priority_tier = prioritized_df$priority_tier[i],
        priority_reason = prioritized_df$priority_reason[i]
      )
    })

    list(
      success = TRUE,
      meta = list(
        generated_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC", tz = "UTC"),
        r_version = R.version.string,
        planning_start_date = format(as.Date(start_date), "%Y-%m-%d"),
        daily_study_hours = daily_hours
      ),
      summary = schedule_result$summary,
      subjects = subjects_list,
      timetable = schedule_result$timetable,
      audit = schedule_result$subject_audit
    )
  }, error = function(e) {
    list(
      success = FALSE,
      error = e$message
    )
  })
}
