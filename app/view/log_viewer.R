# View: Log Viewer module – display, filter, search logs
# https://go.appsilon.com/rhino-project-structure

box::use(
  shiny[
    NS, moduleServer, tagList, tags, div, icon, span,
    textInput, reactive, req,
    observe, observeEvent, reactiveVal,
    uiOutput, renderUI,
  ],
  reactable[reactable, reactableOutput, renderReactable, colDef, JS],
)

#' @export
ui <- function(id) {
  ns <- NS(id)
  tagList(
    # ── Header row ───────────────────────────────────────────
    div(
      class = "log-header",
      tags$h4(
        class = "log-title",
        icon("magnifying-glass-chart"),
        " Log Viewer"
      )
    ),

    # ── Summary value boxes ──────────────────────────────────
    uiOutput(ns("summary_boxes")),

    # ── Filter bar ───────────────────────────────────────────
    div(
      class = "filter-bar",
      div(
        class = "filter-checks",
        id = ns("filter_btns"),
        lapply(c("ERROR", "WARN", "INFO", "DEBUG", "TRACE", "STDOUT", "STDERR"), function(lvl) {
          tags$button(
            type = "button",
            class = paste0("filter-btn filter-", tolower(lvl), " active"),
            `data-level` = lvl,
            lvl
          )
        }),
        # Hidden input to relay selected levels to Shiny
        tags$input(
          type = "hidden",
          id = ns("level_filter"),
          value = "ERROR,WARN,INFO,DEBUG,TRACE,STDOUT,STDERR"
        )
      ),
      div(
        class = "filter-search",
        textInput(
          ns("search_text"),
          label = NULL,
          placeholder = "Search logs...",
          width = "100%"
        )
      )
    ),
    # ── JS: filter-button toggle logic ──────────────────────
    tags$script(shiny::HTML(sprintf("
      (function() {
        document.addEventListener('DOMContentLoaded', function() {
          var container = document.getElementById('%s');
          if (!container) return;
          var hiddenInput = document.getElementById('%s');

          function syncInput() {
            var active = container.querySelectorAll('.filter-btn.active');
            var vals = Array.prototype.map.call(active, function(b) { return b.getAttribute('data-level'); });
            hiddenInput.value = vals.join(',');
            Shiny.setInputValue('%s', vals);
          }

          container.addEventListener('click', function(e) {
            var btn = e.target.closest('.filter-btn');
            if (!btn) return;
            btn.classList.toggle('active');
            syncInput();
          });
        });
      })();
    ", ns("filter_btns"), ns("level_filter"), ns("level_filter")))),

    # ── Log table ────────────────────────────────────────────
    div(
      class = "log-table-container",
      reactableOutput(ns("log_table"), height = "100%")
    )
  )
}

#' @export
server <- function(id, logs_reactive) {
  moduleServer(id, function(input, output, session) {

    box::use(
      app/logic/log_parser[level_colors],
    )

    filtered_logs <- reactive({
      req(logs_reactive())
      logs <- logs_reactive()
      if (is.null(logs) || nrow(logs) == 0) return(logs)

      # Filter by level
      lvls <- input$level_filter
      if (!is.null(lvls) && length(lvls) > 0) {
        logs <- logs[logs$level %in% lvls, ]
      }

      # Filter by search text
      if (!is.null(input$search_text) && nchar(input$search_text) > 0) {
        pattern <- input$search_text
        logs <- logs[grepl(pattern, logs$message, ignore.case = TRUE), ]
      }

      logs
    })

    # ── Summary boxes ──────────────────────────────────────────
    output$summary_boxes <- renderUI({
      logs <- logs_reactive()
      if (is.null(logs) || nrow(logs) == 0) {
        return(div(
          class = "summary-bar empty-state",
          div(
            class = "empty-icon",
            icon("terminal", class = "fa-3x")
          ),
          tags$p("No logs loaded yet."),
          tags$p(
            style = "font-size: 0.75rem; color: #5a6a82; margin-top: 4px;",
            "Select content and a job from the sidebar, then click Fetch Logs."
          )
        ))
      }

      levels <- c("ERROR", "WARN", "INFO", "DEBUG", "STDOUT", "STDERR")
      counts <- vapply(levels, function(l) sum(logs$level == l), integer(1))

      # Colour map for backgrounds (light theme)
      bg_map <- c(
        ERROR  = "rgba(220, 38, 38, 0.08)",
        WARN   = "rgba(217, 119, 6, 0.08)",
        INFO   = "rgba(37, 99, 235, 0.07)",
        DEBUG  = "rgba(124, 58, 237, 0.07)",
        STDOUT = "rgba(5, 150, 105, 0.07)",
        STDERR = "rgba(225, 29, 72, 0.07)"
      )
      fg_map <- c(
        ERROR  = "#dc2626",
        WARN   = "#d97706",
        INFO   = "#2563eb",
        DEBUG  = "#7c3aed",
        STDOUT = "#059669",
        STDERR = "#e11d48"
      )

      div(
        class = "summary-bar",
        # Total badge
        div(
          class = "summary-box",
          style = "background: var(--summary-total-bg); color: var(--summary-total-color); border: 1px solid var(--summary-total-border);",
          div(class = "summary-count", nrow(logs)),
          div(class = "summary-label", "TOTAL")
        ),
        # Per-level boxes
        lapply(seq_along(levels), function(i) {
          div(
            class = "summary-box",
            style = paste0(
              "background:", bg_map[levels[i]], ";",
              "color:", fg_map[levels[i]], ";",
              "border: 1px solid ", gsub("0\\.[0-9]+\\)", "0.12)", bg_map[levels[i]]), ";"
            ),
            div(class = "summary-count", counts[i]),
            div(class = "summary-label", levels[i])
          )
        })
      )
    })

    # ── Log table ──────────────────────────────────────────────
    output$log_table <- renderReactable({
      logs <- filtered_logs()
      if (is.null(logs) || nrow(logs) == 0) {
        return(reactable(
          data.frame(message = "No log entries to display."),
          columns = list(message = colDef(name = ""))
        ))
      }

      reactable(
        logs,
        compact = TRUE,
        borderless = TRUE,
        striped = FALSE,
        highlight = TRUE,
        defaultPageSize = 100,
        paginationType = "jump",
        showPageSizeOptions = TRUE,
        pageSizeOptions = c(50, 100, 250, 500),
        theme = reactable::reactableTheme(
          color = "#334155",
          backgroundColor = "transparent",
          borderColor = "rgba(0,0,0,0.06)",
          stripedColor = "rgba(0,0,0,0.02)",
          highlightColor = "rgba(0,0,0,0.03)",
          headerStyle = list(
            color = "#64748b",
            fontWeight = 600,
            fontSize = "11px",
            textTransform = "uppercase",
            letterSpacing = "0.05em",
            borderBottomColor = "rgba(0,0,0,0.08)"
          ),
          cellStyle = list(
            fontFamily = "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
            fontSize = "12.5px",
            lineHeight = "1.6"
          ),
          paginationStyle = list(color = "#64748b")
        ),
        columns = list(
          line_number = colDef(
            name = "#",
            width = 60,
            style = list(color = "#94a3b8", fontWeight = 500)
          ),
          timestamp = colDef(
            name = "Timestamp",
            width = 170,
            cell = JS("function(cellInfo) {
              var raw = cellInfo.value;
              if (!raw) return raw;
              var d = new Date(raw);
              if (isNaN(d)) return raw;
              var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
              var date = months[d.getMonth()] + ' ' + d.getDate();
              var time = ('0'+d.getHours()).slice(-2) + ':' + ('0'+d.getMinutes()).slice(-2) + ':' + ('0'+d.getSeconds()).slice(-2);
              return React.createElement('span', {
                style: { color: '#64748b', whiteSpace: 'nowrap' }
              }, date + ', ' + time);
            }")
          ),
          source = colDef(show = FALSE),
          level = colDef(
            name = "Level",
            width = 90,
            cell = JS("function(cellInfo) {
              const colors = {
                'ERROR':  { bg: 'rgba(220,38,38,0.1)', fg: '#dc2626' },
                'WARN':   { bg: 'rgba(217,119,6,0.1)', fg: '#d97706' },
                'INFO':   { bg: 'rgba(37,99,235,0.08)', fg: '#2563eb' },
                'DEBUG':  { bg: 'rgba(124,58,237,0.08)', fg: '#7c3aed' },
                'TRACE':  { bg: 'rgba(107,114,128,0.08)', fg: '#6b7280' },
                'STDERR': { bg: 'rgba(225,29,72,0.08)', fg: '#e11d48' },
                'STDOUT': { bg: 'rgba(5,150,105,0.08)', fg: '#059669' }
              };
              const c = colors[cellInfo.value] || { bg: 'rgba(0,0,0,0.04)', fg: '#64748b' };
              return React.createElement('span', {
                style: {
                  backgroundColor: c.bg,
                  color: c.fg,
                  padding: '3px 10px',
                  borderRadius: '6px',
                  fontSize: '10.5px',
                  fontWeight: 700,
                  letterSpacing: '0.04em',
                  fontFamily: 'JetBrains Mono, monospace'
                }
              }, cellInfo.value);
            }")
          ),
          message = colDef(
            name = "Message",
            minWidth = 400,
            style = JS("function(rowInfo) {
              const level = rowInfo.row['level'];
              const opacityMap = {
                'ERROR': 'rgba(220, 38, 38, 0.04)',
                'WARN': 'rgba(217, 119, 6, 0.04)',
                'STDERR': 'rgba(225, 29, 72, 0.04)'
              };
              const bg = opacityMap[level] || 'transparent';
              return { backgroundColor: bg };
            }")
          )
        ),
        rowStyle = JS("function(rowInfo) {
          const level = rowInfo.row['level'];
          if (level === 'ERROR') return { borderLeft: '3px solid #dc2626' };
          if (level === 'WARN') return { borderLeft: '3px solid #d97706' };
          if (level === 'STDERR') return { borderLeft: '3px solid #e11d48' };
          return { borderLeft: '3px solid transparent' };
        }")
      )
    })
  })
}
