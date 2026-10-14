/**
 * ==============================================================================
 * web/script.js - Smart Study Session Planner
 * Interactive Client Logic & R Backend Integration
 * Pure Vanilla JavaScript • Zero External Libraries
 * ==============================================================================
 */

// Application State
const state = {
  subjects: [],
  startDate: '',
  dailyHours: 4.0,
  currentPlan: null,
  apiBaseUrl: '',
  backendConnected: false,
  activeFilter: 'all'
};

// DOM Element References
const dom = {
  // Header & Status
  backendStatusBadge: document.getElementById('backend-status-badge'),
  backendStatusText: document.getElementById('backend-status-text'),
  btnLoadSample: document.getElementById('btn-load-sample'),
  btnClearAll: document.getElementById('btn-clear-all'),

  // Planner Settings
  inputStartDate: document.getElementById('input-start-date'),
  inputDailyHours: document.getElementById('input-daily-hours'),

  // Subject Form
  subjectForm: document.getElementById('subject-form'),
  subjectFormTitle: document.getElementById('subject-form-title'),
  editSubjectIndex: document.getElementById('edit-subject-index'),
  inputSubjectName: document.getElementById('input-subject-name'),
  inputExamDate: document.getElementById('input-exam-date'),
  selectDifficulty: document.getElementById('select-difficulty'),
  inputPrepHours: document.getElementById('input-prep-hours'),
  btnSaveSubject: document.getElementById('btn-save-subject'),
  btnCancelEdit: document.getElementById('btn-cancel-edit'),
  formValidationAlert: document.getElementById('form-validation-alert'),
  formValidationMsg: document.getElementById('form-validation-msg'),

  // Subjects Container
  subjectCountBadge: document.getElementById('subject-count-badge'),
  subjectsContainer: document.getElementById('subjects-container'),
  btnGeneratePlan: document.getElementById('btn-generate-plan'),

  // Workspace View States
  emptyStateCard: document.getElementById('empty-state-card'),
  btnEmptyLoadSample: document.getElementById('btn-empty-load-sample'),
  loadingStateCard: document.getElementById('loading-state-card'),
  resultsDashboard: document.getElementById('results-dashboard'),

  // KPI Metrics
  kpiSubjectsHorizon: document.getElementById('kpi-subjects-horizon'),
  kpiDateRange: document.getElementById('kpi-date-range'),
  kpiRequiredHours: document.getElementById('kpi-required-hours'),
  kpiDailyTarget: document.getElementById('kpi-daily-target'),
  kpiScheduledHours: document.getElementById('kpi-scheduled-hours'),
  kpiCompletionRate: document.getElementById('kpi-completion-rate'),
  kpiCardVerdict: document.getElementById('kpi-card-verdict'),
  kpiVerdictText: document.getElementById('kpi-verdict-text'),
  kpiUnscheduledText: document.getElementById('kpi-unscheduled-text'),

  // Feasibility Notice
  feasibilityNotice: document.getElementById('feasibility-notice'),
  noticeTitle: document.getElementById('notice-title'),
  noticeDesc: document.getElementById('notice-desc'),

  // Tabs
  tabButtons: document.querySelectorAll('.tab-btn'),
  tabPanes: document.querySelectorAll('.tab-pane'),

  // Timetable View
  selectFilterSubject: document.getElementById('select-filter-subject'),
  filterDaysCount: document.getElementById('filter-days-count'),
  timetableTimelineContainer: document.getElementById('timetable-timeline-container'),

  // Priority Table
  priorityTableBody: document.getElementById('priority-table-body'),

  // Audit Table
  auditTableBody: document.getElementById('audit-table-body')
};

/**
 * Determine API Base URL dynamically
 * Supports both direct Plumber hosting (http://127.0.0.1:8000)
 * and file:// or alternate local test ports.
 */
function resolveApiBaseUrl() {
  const origin = window.location.origin;
  if (origin && origin.startsWith('http') && !origin.includes('file:')) {
    return origin;
  }
  return 'http://127.0.0.1:8000';
}

/**
 * Format Date helper (YYYY-MM-DD)
 */
function formatDate(dateObj) {
  const d = new Date(dateObj);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Add days to a date string
 */
function addDays(dateStr, days) {
  const d = new Date(dateStr);
  d.setDate(d.getDate() + days);
  return formatDate(d);
}

/**
 * Calculate calendar days difference
 */
function getDaysDiff(startStr, endStr) {
  const s = new Date(startStr);
  const e = new Date(endStr);
  const diffTime = e - s;
  return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
}

/**
 * Initialize Default Inputs
 */
function initDefaults() {
  state.apiBaseUrl = resolveApiBaseUrl();

  // Set default start date to today
  const today = formatDate(new Date());
  state.startDate = today;
  dom.inputStartDate.value = today;
  dom.inputStartDate.min = today;

  // Set minimum exam date to tomorrow
  const tomorrow = addDays(today, 1);
  dom.inputExamDate.value = addDays(today, 7);
  dom.inputExamDate.min = tomorrow;

  state.dailyHours = parseFloat(dom.inputDailyHours.value) || 4.0;
}

/**
 * Check R Backend Health
 */
async function checkBackendHealth() {
  try {
    dom.backendStatusBadge.className = 'status-badge status-checking';
    dom.backendStatusText.textContent = 'Connecting to R...';

    const res = await fetch(`${state.apiBaseUrl}/api/health`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' }
    });

    if (res.ok) {
      const data = await res.json();
      state.backendConnected = true;
      dom.backendStatusBadge.className = 'status-badge status-connected';
      dom.backendStatusText.textContent = 'Connected to R backend';
      dom.backendStatusBadge.title = `R Service Active (${data.r_version || 'R 4.6.1'})`;
      return true;
    } else {
      throw new Error(`HTTP ${res.status}`);
    }
  } catch (err) {
    state.backendConnected = false;
    dom.backendStatusBadge.className = 'status-badge status-error';
    dom.backendStatusText.textContent = 'R backend offline';
    dom.backendStatusBadge.title = `Could not reach R API at ${state.apiBaseUrl}. Ensure Rscript R/main.R is running.`;
    return false;
  }
}

/**
 * Display Validation Alert in Subject Form
 */
function showFormAlert(message) {
  dom.formValidationMsg.textContent = message;
  dom.formValidationAlert.style.display = 'flex';
}

function hideFormAlert() {
  dom.formValidationAlert.style.display = 'none';
}

/**
 * Render Configured Subjects List in Sidebar
 */
function renderSubjectsList() {
  dom.subjectCountBadge.textContent = state.subjects.length;
  dom.subjectsContainer.innerHTML = '';

  if (state.subjects.length === 0) {
    dom.subjectsContainer.innerHTML = `
      <div class="empty-subjects-placeholder">
        No subjects configured yet.<br>
        Add your exams above or load sample data.
      </div>
    `;
    return;
  }

  state.subjects.forEach((subj, idx) => {
    const daysLeft = getDaysDiff(state.startDate, subj.exam_date);
    const diffClass = `badge-${subj.difficulty.toLowerCase()}`;

    const card = document.createElement('div');
    card.className = 'subject-item-card';
    card.innerHTML = `
      <div class="subject-info-col">
        <div class="subject-name-row">
          <span class="subject-item-name" title="${escapeHtml(subj.subject)}">${escapeHtml(subj.subject)}</span>
          <span class="badge ${diffClass}">${subj.difficulty}</span>
        </div>
        <div class="subject-meta-row">
          <span>📅 Exam: ${subj.exam_date} (${daysLeft}d left)</span>
          <span>⏱️ ${subj.estimated_hours}h prep</span>
        </div>
      </div>
      <div class="subject-actions">
        <button class="btn-icon" data-action="edit" data-index="${idx}" title="Edit subject">Edit</button>
        <button class="btn-icon btn-icon-danger" data-action="delete" data-index="${idx}" title="Remove subject">✕</button>
      </div>
    `;
    dom.subjectsContainer.appendChild(card);
  });
}

/**
 * Escape HTML to prevent injection
 */
function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/**
 * Reset Subject Input Form
 */
function resetSubjectForm() {
  dom.subjectForm.reset();
  dom.editSubjectIndex.value = '-1';
  dom.subjectFormTitle.textContent = 'Add Exam Subject';
  dom.btnSaveSubject.textContent = '+ Add Subject';
  dom.btnCancelEdit.style.display = 'none';
  dom.inputSubjectName.focus();
  hideFormAlert();

  // Restore reasonable default dates
  dom.inputExamDate.value = addDays(state.startDate || formatDate(new Date()), 7);
  dom.inputPrepHours.value = 12;
  dom.selectDifficulty.value = 'Medium';
}

/**
 * Populate Form for Editing Subject
 */
function editSubject(idx) {
  const subj = state.subjects[idx];
  if (!subj) return;

  dom.editSubjectIndex.value = idx;
  dom.inputSubjectName.value = subj.subject;
  dom.inputExamDate.value = subj.exam_date;
  dom.selectDifficulty.value = subj.difficulty;
  dom.inputPrepHours.value = subj.estimated_hours;

  dom.subjectFormTitle.textContent = `Edit: ${subj.subject}`;
  dom.btnSaveSubject.textContent = 'Save Changes';
  dom.btnCancelEdit.style.display = 'inline-flex';
  hideFormAlert();
  dom.inputSubjectName.focus();
}

/**
 * Remove Subject
 */
function deleteSubject(idx) {
  state.subjects.splice(idx, 1);
  renderSubjectsList();
  if (state.subjects.length === 0) {
    showEmptyState();
  }
}

/**
 * Handle Subject Form Submission (Add or Update)
 */
dom.subjectForm.addEventListener('submit', (e) => {
  e.preventDefault();
  hideFormAlert();

  const name = dom.inputSubjectName.value.trim();
  const examDate = dom.inputExamDate.value;
  const difficulty = dom.selectDifficulty.value;
  const prepHours = parseFloat(dom.inputPrepHours.value);
  const editIdx = parseInt(dom.editSubjectIndex.value, 10);

  // 1. Validate Subject Name
  if (!name) {
    showFormAlert('Please enter a descriptive subject name.');
    dom.inputSubjectName.focus();
    return;
  }

  // 2. Validate Duplicate Names (case-insensitive)
  const isDuplicate = state.subjects.some((s, idx) => {
    return idx !== editIdx && s.subject.toLowerCase() === name.toLowerCase();
  });
  if (isDuplicate) {
    showFormAlert(`Subject "${name}" already exists. Please choose a unique name.`);
    dom.inputSubjectName.focus();
    return;
  }

  // 3. Validate Exam Date strictly after Start Date
  if (!examDate) {
    showFormAlert('Please select a valid exam date.');
    dom.inputExamDate.focus();
    return;
  }
  if (examDate <= state.startDate) {
    showFormAlert(`Exam date (${examDate}) must be strictly after the planning start date (${state.startDate}). Preparation sessions cannot be scheduled on or after the exam date.`);
    dom.inputExamDate.focus();
    return;
  }

  // 4. Validate Preparation Hours
  if (isNaN(prepHours) || prepHours <= 0) {
    showFormAlert('Estimated preparation hours must be a positive number greater than 0.');
    dom.inputPrepHours.focus();
    return;
  }
  if (prepHours > 200) {
    showFormAlert('Estimated hours exceeds 200h. Please enter a realistic single-exam preparation target.');
    dom.inputPrepHours.focus();
    return;
  }

  const subjectRecord = {
    subject: name,
    exam_date: examDate,
    difficulty: difficulty,
    estimated_hours: prepHours
  };

  if (editIdx >= 0) {
    state.subjects[editIdx] = subjectRecord;
  } else {
    state.subjects.push(subjectRecord);
  }

  renderSubjectsList();
  resetSubjectForm();
});

// Cancel Edit Button
dom.btnCancelEdit.addEventListener('click', resetSubjectForm);

// Delegate Edit / Delete clicks in subjects list
dom.subjectsContainer.addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-action]');
  if (!btn) return;

  const action = btn.dataset.action;
  const index = parseInt(btn.dataset.index, 10);

  if (action === 'edit') {
    editSubject(index);
  } else if (action === 'delete') {
    deleteSubject(index);
  }
});

// Update Start Date
dom.inputStartDate.addEventListener('change', () => {
  state.startDate = dom.inputStartDate.value;
  dom.inputExamDate.min = addDays(state.startDate, 1);
  renderSubjectsList();
});

// Update Daily Hours
dom.inputDailyHours.addEventListener('change', () => {
  const val = parseFloat(dom.inputDailyHours.value);
  if (!isNaN(val) && val >= 0.5 && val <= 16) {
    state.dailyHours = val;
  }
});

/**
 * Load Sample Subjects Data
 */
async function loadSampleData() {
  hideFormAlert();

  // Try fetching from backend API first
  try {
    const res = await fetch(`${state.apiBaseUrl}/api/sample`, {
      method: 'GET',
      headers: { 'Accept': 'application/json' }
    });

    if (res.ok) {
      const data = await res.json();
      if (data.subjects && data.subjects.length > 0) {
        state.subjects = data.subjects;
        if (data.start_date) {
          state.startDate = data.start_date;
          dom.inputStartDate.value = data.start_date;
        }
        if (data.daily_hours) {
          state.dailyHours = data.daily_hours;
          dom.inputDailyHours.value = data.daily_hours;
        }
        renderSubjectsList();
        generateStudyPlan();
        return;
      }
    }
  } catch (err) {
    console.warn('API sample load failed, falling back to client sample dataset:', err);
  }

  // Fallback realistic sample data if backend API is not yet active
  const baseDate = state.startDate || formatDate(new Date());
  state.subjects = [
    { subject: 'Operating Systems', exam_date: addDays(baseDate, 6), difficulty: 'Hard', estimated_hours: 16 },
    { subject: 'Database Systems', exam_date: addDays(baseDate, 10), difficulty: 'Medium', estimated_hours: 12 },
    { subject: 'Computer Networks', exam_date: addDays(baseDate, 14), difficulty: 'Hard', estimated_hours: 18 },
    { subject: 'Software Engineering', exam_date: addDays(baseDate, 18), difficulty: 'Medium', estimated_hours: 10 },
    { subject: 'Web Technologies', exam_date: addDays(baseDate, 22), difficulty: 'Easy', estimated_hours: 8 }
  ];

  renderSubjectsList();
  generateStudyPlan();
}

dom.btnLoadSample.addEventListener('click', loadSampleData);
dom.btnEmptyLoadSample.addEventListener('click', loadSampleData);

/**
 * Clear All Subjects & Reset
 */
dom.btnClearAll.addEventListener('click', () => {
  if (state.subjects.length > 0 && !confirm('Are you sure you want to clear all subjects and reset the planner?')) {
    return;
  }
  state.subjects = [];
  state.currentPlan = null;
  renderSubjectsList();
  resetSubjectForm();
  showEmptyState();
});

/**
 * State Transition Helpers
 */
function showEmptyState() {
  dom.emptyStateCard.style.display = 'block';
  dom.loadingStateCard.style.display = 'none';
  dom.resultsDashboard.style.display = 'none';
}

function showLoadingState() {
  dom.emptyStateCard.style.display = 'none';
  dom.loadingStateCard.style.display = 'block';
  dom.resultsDashboard.style.display = 'none';
}

function showResultsDashboard() {
  dom.emptyStateCard.style.display = 'none';
  dom.loadingStateCard.style.display = 'none';
  dom.resultsDashboard.style.display = 'block';
}

/**
 * Call R Backend API to Generate Study Plan
 */
async function generateStudyPlan() {
  if (state.subjects.length === 0) {
    showFormAlert('Please add at least one subject before generating a study timetable.');
    return;
  }

  showLoadingState();

  const payload = {
    start_date: state.startDate,
    daily_hours: state.dailyHours,
    subjects: state.subjects
  };

  try {
    const res = await fetch(`${state.apiBaseUrl}/api/plan`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    if (!res.ok) {
      throw new Error(`R backend returned HTTP ${res.status}: ${res.statusText}`);
    }

    const data = await res.json();

    if (!data.success) {
      throw new Error(data.error || 'Failed to generate study plan in R.');
    }

    state.currentPlan = data;
    state.backendConnected = true;
    dom.backendStatusBadge.className = 'status-badge status-connected';
    dom.backendStatusText.textContent = 'Connected to R backend';

    renderPlanDashboard(data);
    showResultsDashboard();
  } catch (err) {
    console.error('Study plan generation failed:', err);
    state.backendConnected = false;
    dom.backendStatusBadge.className = 'status-badge status-error';
    dom.backendStatusText.textContent = 'R backend offline';

    alert(
      `Could not connect to the R backend service at ${state.apiBaseUrl}.\n\n` +
      `Please ensure the R backend is running in your terminal:\n` +
      `Rscript R/main.R\n\n` +
      `Details: ${err.message}`
    );
    showEmptyState();
  }
}

dom.btnGeneratePlan.addEventListener('click', generateStudyPlan);

/**
 * Render Complete Study Plan Dashboard
 */
function renderPlanDashboard(planData) {
  const summary = planData.summary;
  const subjects = planData.subjects;
  const timetable = planData.timetable;
  const audit = planData.audit;

  // 1. KPI Cards
  dom.kpiSubjectsHorizon.textContent = `${summary.total_subjects} Subj / ${summary.total_planning_days} Days`;
  dom.kpiDateRange.textContent = `${summary.start_date} to ${summary.horizon_end_date}`;

  dom.kpiRequiredHours.textContent = `${summary.total_required_hours.toFixed(1)} hrs`;
  dom.kpiDailyTarget.textContent = `${summary.active_study_days} active days @ ${summary.daily_available_hours}h limit`;

  dom.kpiScheduledHours.textContent = `${summary.total_scheduled_hours.toFixed(1)} hrs`;
  dom.kpiCompletionRate.textContent = `${summary.overall_completion_rate.toFixed(1)}% of total goal scheduled`;

  if (summary.total_unscheduled_hours > 0) {
    dom.kpiVerdictText.textContent = 'Time Deficit';
    dom.kpiVerdictText.style.color = '#a13522';
    dom.kpiUnscheduledText.textContent = `${summary.total_unscheduled_hours.toFixed(1)} hrs unscheduled`;
    dom.kpiUnscheduledText.style.color = '#a13522';

    // Show Feasibility Alert Notice
    dom.noticeTitle.textContent = `Insufficient Preparation Time (${summary.total_unscheduled_hours.toFixed(1)} Hours Unscheduled)`;
    dom.noticeDesc.textContent =
      `Based on your daily limit of ${summary.daily_available_hours} hours/day and upcoming exam deadlines, ` +
      `there are not enough calendar days before exams to accommodate all required preparation hours. ` +
      `Consider increasing daily study hours or focusing on high-priority subjects first.`;
    dom.feasibilityNotice.style.display = 'flex';
  } else {
    dom.kpiVerdictText.textContent = 'Feasible';
    dom.kpiVerdictText.style.color = '#286339';
    dom.kpiUnscheduledText.textContent = 'All hours scheduled';
    dom.kpiUnscheduledText.style.color = '#286339';
    dom.feasibilityNotice.style.display = 'none';
  }

  // 2. Populate Subject Filter Dropdown
  dom.selectFilterSubject.innerHTML = '<option value="all">All Subjects</option>';
  subjects.forEach(s => {
    const opt = document.createElement('option');
    opt.value = s.subject;
    opt.textContent = `${s.subject} (Rank #${s.rank})`;
    dom.selectFilterSubject.appendChild(opt);
  });
  dom.selectFilterSubject.value = state.activeFilter;

  // 3. Render Timetable
  renderTimetable(timetable, state.activeFilter);

  // 4. Render Priority Table
  renderPriorityTable(subjects);

  // 5. Render Feasibility Audit Table
  renderAuditTable(audit);
}

/**
 * Render Daily Timetable Cards
 */
function renderTimetable(timetable, filterSubject) {
  dom.timetableTimelineContainer.innerHTML = '';

  let visibleDaysCount = 0;

  timetable.forEach(day => {
    // Check if filtering by subject
    let filteredSessions = day.sessions;
    if (filterSubject && filterSubject !== 'all') {
      filteredSessions = day.sessions.filter(s => s.subject === filterSubject);
    }

    const hasExamsToday = day.exams_today && day.exams_today.length > 0;
    const isSubjectExamToday = hasExamsToday && (filterSubject === 'all' || day.exams_today.includes(filterSubject));

    // If filtering and no sessions or exams for this subject, skip day
    if (filterSubject !== 'all' && filteredSessions.length === 0 && !isSubjectExamToday) {
      return;
    }

    visibleDaysCount++;

    const dayCard = document.createElement('div');
    dayCard.className = `timeline-day-card ${hasExamsToday ? 'day-has-exam' : ''}`;

    let examBannerHtml = '';
    if (hasExamsToday) {
      examBannerHtml = `
        <div class="day-exam-banner">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"></path>
          </svg>
          <span>EXAM TODAY: ${escapeHtml(day.exams_today.join(', '))}</span>
        </div>
      `;
    }

    let sessionsHtml = '';
    if (filteredSessions.length === 0) {
      sessionsHtml = `<div class="rest-day-note">No preparation sessions scheduled for this day (Rest / buffer day).</div>`;
    } else {
      sessionsHtml = '<div class="day-sessions-grid">';
      filteredSessions.forEach(sess => {
        const diffClass = `badge-${sess.difficulty.toLowerCase()}`;
        sessionsHtml += `
          <div class="session-strip">
            <div class="session-main">
              <span class="session-subject-name">${escapeHtml(sess.subject)}</span>
              <span class="badge ${diffClass}">${sess.difficulty}</span>
              <span class="session-hours-badge">${sess.hours.toFixed(1)} hrs</span>
            </div>
            <div class="session-meta">
              <span class="session-focus-pill">${escapeHtml(sess.session_focus)}</span>
              <span class="session-days-away">${sess.days_to_exam}d until exam</span>
            </div>
          </div>
        `;
      });
      sessionsHtml += '</div>';
    }

    dayCard.innerHTML = `
      <div class="day-header-row">
        <div class="day-title-group">
          <span class="day-index-pill">Day ${day.day_index}</span>
          <span class="day-date-text">${day.date}</span>
          <span class="day-name-sub">(${day.day_of_week})</span>
        </div>
        <div class="day-capacity-badge">
          Study: ${day.scheduled_hours.toFixed(1)} / ${day.available_hours.toFixed(1)}h (${day.utilization_percent.toFixed(0)}%)
        </div>
      </div>
      ${examBannerHtml}
      ${sessionsHtml}
    `;

    dom.timetableTimelineContainer.appendChild(dayCard);
  });

  dom.filterDaysCount.textContent = visibleDaysCount;
}

// Subject Filter Dropdown Event
dom.selectFilterSubject.addEventListener('change', () => {
  state.activeFilter = dom.selectFilterSubject.value;
  if (state.currentPlan) {
    renderTimetable(state.currentPlan.timetable, state.activeFilter);
  }
});

/**
 * Render Priority Ranking Table
 */
function renderPriorityTable(subjects) {
  dom.priorityTableBody.innerHTML = '';

  subjects.forEach(s => {
    let tierClass = 'badge-priority-medium';
    if (s.priority_tier === 'High Priority') tierClass = 'badge-priority-high';
    else if (s.priority_tier === 'Low Priority') tierClass = 'badge-priority-low';

    const row = document.createElement('tr');
    row.innerHTML = `
      <td><span class="rank-pill">#${s.rank}</span></td>
      <td><strong>${escapeHtml(s.subject)}</strong></td>
      <td>${s.exam_date}</td>
      <td><strong>${s.days_remaining}</strong> days</td>
      <td><span class="badge badge-${s.difficulty.toLowerCase()}">${s.difficulty} (${s.difficulty_weight}x)</span></td>
      <td>${s.daily_demand.toFixed(2)}h / day</td>
      <td>
        <span class="badge ${tierClass}">${s.priority_score.toFixed(1)} / 100</span>
      </td>
      <td><small style="color: var(--text-secondary);">${escapeHtml(s.priority_reason)}</small></td>
    `;
    dom.priorityTableBody.appendChild(row);
  });
}

/**
 * Render Feasibility Audit Table
 */
function renderAuditTable(auditList) {
  dom.auditTableBody.innerHTML = '';

  auditList.forEach(item => {
    const isDeficit = item.unscheduled_hours > 0;
    const statusBadge = isDeficit
      ? `<span class="badge badge-hard">Time Deficit (${item.unscheduled_hours.toFixed(1)}h)</span>`
      : `<span class="badge badge-easy">Fully Scheduled</span>`;

    const progressFillClass = isDeficit ? 'progress-fill-warning' : 'progress-fill';

    const row = document.createElement('tr');
    row.innerHTML = `
      <td><strong>${escapeHtml(item.subject)}</strong></td>
      <td>${item.exam_date}</td>
      <td>${item.required_hours.toFixed(1)}h</td>
      <td>${item.scheduled_hours.toFixed(1)}h</td>
      <td><strong style="color: ${isDeficit ? '#a13522' : '#286339'};">${item.unscheduled_hours.toFixed(1)}h</strong></td>
      <td>
        <div>${item.completion_rate.toFixed(1)}%</div>
        <div class="progress-track">
          <div class="${progressFillClass}" style="width: ${Math.min(100, item.completion_rate)}%;"></div>
        </div>
      </td>
      <td>${statusBadge}</td>
      <td><small style="color: var(--text-secondary);">${escapeHtml(item.feasibility_note)}</small></td>
    `;
    dom.auditTableBody.appendChild(row);
  });
}

/**
 * Tab Navigation Handler
 */
dom.tabButtons.forEach(btn => {
  btn.addEventListener('click', () => {
    dom.tabButtons.forEach(b => {
      b.classList.remove('active');
      b.setAttribute('aria-selected', 'false');
    });
    dom.tabPanes.forEach(p => {
      p.style.display = 'none';
      p.classList.remove('active');
    });

    btn.classList.add('active');
    btn.setAttribute('aria-selected', 'true');

    const targetId = btn.dataset.tab;
    const targetPane = document.getElementById(targetId);
    if (targetPane) {
      targetPane.style.display = 'block';
      targetPane.classList.add('active');
    }
  });
});

/**
 * Application Bootstrap
 */
window.addEventListener('DOMContentLoaded', async () => {
  initDefaults();
  renderSubjectsList();
  showEmptyState();

  // Check backend health
  await checkBackendHealth();

  // Automatically load sample data so application is interactive on startup
  loadSampleData();
});
