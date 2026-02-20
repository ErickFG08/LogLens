# View: Log Viewer module – display, filter, search logs
# https://go.appsilon.com/rhino-project-structure

box::use(
  shiny[
    NS, moduleServer, tagList, tags, div, icon, span,
    textInput, reactive, req,
    observe, observeEvent, reactiveVal,
    uiOutput, renderUI,
    downloadButton, downloadHandler,
  ],
  reactable[reactable, reactableOutput, renderReactable, colDef, JS],
  utils[write.csv],
  writexl[write_xlsx],
)

box::use(
  app/logic/log_parser[level_colors],
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
      ),
      div(
        class = "export-buttons",
        downloadButton(
          ns("export_csv"),
          label = tags$span(icon("file-csv"), " CSV"),
          class = "btn-export btn-export-csv"
        ),
        downloadButton(
          ns("export_excel"),
          label = tags$span(icon("file-excel"), " Excel"),
          class = "btn-export btn-export-excel"
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
        defaultSorted = list(line_number = "desc"),
        defaultPageSize = 500,
        paginationType = "jump",
        showPageSizeOptions = TRUE,
        pageSizeOptions = c(50, 100, 250, 500),
        theme = reactable::reactableTheme(
          color = "var(--table-text)",
          backgroundColor = "transparent",
          borderColor = "var(--table-border)",
          stripedColor = "var(--table-stripe)",
          highlightColor = "var(--table-highlight)",
          headerStyle = list(
            color = "var(--table-header-color)",
            fontWeight = 600,
            fontSize = "11px",
            textTransform = "uppercase",
            letterSpacing = "0.05em",
            borderBottomColor = "var(--table-header-border)"
          ),
          cellStyle = list(
            fontFamily = "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
            fontSize = "12.5px",
            lineHeight = "1.6"
          ),
          paginationStyle = list(color = "var(--text-muted)")
        ),
        columns = list(
          line_number = colDef(
            name = "#",
            width = 60,
            style = list(color = "var(--text-dim)", fontWeight = 500)
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
                style: { color: 'var(--text-muted)', whiteSpace: 'nowrap' }
              }, date + ', ' + time);
            }")
          ),
          source = colDef(show = FALSE),
          level = colDef(
            name = "Level",
            width = 90,
            cell = JS("function(cellInfo) {
              var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
              var colors = {
                'ERROR':  { bg: 'rgba(220,38,38,' + (isDark ? '0.2' : '0.1') + ')', fg: isDark ? '#f87171' : '#dc2626' },
                'WARN':   { bg: 'rgba(217,119,6,' + (isDark ? '0.2' : '0.1') + ')', fg: isDark ? '#fbbf24' : '#d97706' },
                'INFO':   { bg: 'rgba(37,99,235,' + (isDark ? '0.2' : '0.08') + ')', fg: isDark ? '#60a5fa' : '#2563eb' },
                'DEBUG':  { bg: 'rgba(124,58,237,' + (isDark ? '0.2' : '0.08') + ')', fg: isDark ? '#a78bfa' : '#7c3aed' },
                'TRACE':  { bg: 'rgba(107,114,128,' + (isDark ? '0.2' : '0.08') + ')', fg: isDark ? '#9ca3af' : '#6b7280' },
                'STDERR': { bg: 'rgba(225,29,72,' + (isDark ? '0.2' : '0.08') + ')', fg: isDark ? '#fb7185' : '#e11d48' },
                'STDOUT': { bg: 'rgba(5,150,105,' + (isDark ? '0.2' : '0.08') + ')', fg: isDark ? '#34d399' : '#059669' }
              };
              var c = colors[cellInfo.value] || { bg: 'rgba(0,0,0,0.04)', fg: 'var(--text-muted)' };
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
              var level = rowInfo.row['level'];
              var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
              var opacityMap = {
                'ERROR': 'rgba(220, 38, 38, ' + (isDark ? '0.08' : '0.04') + ')',
                'WARN': 'rgba(217, 119, 6, ' + (isDark ? '0.08' : '0.04') + ')',
                'STDERR': 'rgba(225, 29, 72, ' + (isDark ? '0.08' : '0.04') + ')'
              };
              var bg = opacityMap[level] || 'transparent';
              return { backgroundColor: bg, color: 'var(--table-text)' };
            }")
          )
        ),
        rowStyle = JS("function(rowInfo) {
          var level = rowInfo.row['level'];
          var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
          if (level === 'ERROR') return { borderLeft: '3px solid ' + (isDark ? '#f87171' : '#dc2626') };
          if (level === 'WARN') return { borderLeft: '3px solid ' + (isDark ? '#fbbf24' : '#d97706') };
          if (level === 'STDERR') return { borderLeft: '3px solid ' + (isDark ? '#fb7185' : '#e11d48') };
          return { borderLeft: '3px solid transparent' };
        }")
      )
    })

    # ── Export: CSV ─────────────────────────────────────────────
    output$export_csv <- downloadHandler(
      filename = function() {
        paste0("loglens_export_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
      },
      content = function(file) {
        logs <- filtered_logs()
        if (is.null(logs) || nrow(logs) == 0) {
          logs <- data.frame(message = "No log entries to export.")
        }
        write.csv(logs, file, row.names = FALSE)
      }
    )

    # ── Export: Excel ──────────────────────────────────────────
    output$export_excel <- downloadHandler(
      filename = function() {
        paste0("loglens_export_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".xlsx")
      },
      content = function(file) {
        logs <- filtered_logs()
        if (is.null(logs) || nrow(logs) == 0) {
          logs <- data.frame(message = "No log entries to export.")
        }
        write_xlsx(logs, file)
      }
    )
  })
}
