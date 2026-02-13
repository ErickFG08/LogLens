# View: Sidebar module – content/job pickers (auto-connects via env vars)
# https://go.appsilon.com/rhino-project-structure

box::use(
  shiny[
    NS, moduleServer, tagList, tags, div, icon,
    actionButton, selectInput,
    observeEvent, reactiveVal, reactive, req, updateSelectInput,
    showNotification, observe, uiOutput, renderUI,
  ],
)

#' @export
ui <- function(id) {
  ns <- NS(id)
  tagList(
    # ── Status indicator ─────────────────────────────────────
    uiOutput(ns("connection_status")),

    # ── Content selector ─────────────────────────────────────
    tags$div(
      class = "sidebar-section",
      div(
        class = "sidebar-heading-row",
        tags$h6(class = "sidebar-heading", icon("cubes"), " Content"),
        actionButton(
          ns("btn_refresh_content"),
          label = NULL,
          icon = icon("arrows-rotate"),
          class = "btn-refresh"
        )
      ),
      selectInput(
        ns("content_picker"),
        label = NULL,
        choices = c("Loading..." = ""),
        width = "100%"
      )
    ),

    # ── Job selector ─────────────────────────────────────────
    tags$div(
      class = "sidebar-section",
      tags$h6(class = "sidebar-heading", icon("clock-rotate-left"), " Job"),
      selectInput(
        ns("job_picker"),
        label = NULL,
        choices = c("Select content first..." = ""),
        width = "100%"
      )
    ),

    # ── Fetch button ─────────────────────────────────────────
    actionButton(
      ns("btn_fetch"),
      label = "Fetch Logs",
      icon = icon("download"),
      width = "100%",
      class = "btn-fetch"
    )
  )
}

#' @export
server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    box::use(
      app/logic/connect_api[create_client, list_content, list_jobs, fetch_log],
      app/logic/log_parser[parse_log],
    )

    client <- reactiveVal(NULL)
    content_df <- reactiveVal(NULL)
    jobs_list <- reactiveVal(NULL)
    parsed_logs <- reactiveVal(NULL)
    connected <- reactiveVal(FALSE)

    # ── Helper: fetch content list and update picker ───────────
    refresh_content <- function() {
      tryCatch({
        cli <- client()
        if (is.null(cli)) {
          cli <- create_client()
          client(cli)
          connected(TRUE)
        }

        ct <- list_content(cli)
        content_df(ct)

        choices <- c("Select content..." = "", stats::setNames(ct$guid, ct$display_name))
        updateSelectInput(session, "content_picker", choices = choices)
      }, error = function(e) {
        connected(FALSE)
        showNotification(
          paste("Connection failed. Check CONNECT_SERVER and CONNECT_API_KEY env vars:", conditionMessage(e)),
          type = "error",
          duration = 10
        )
      })
    }

    # ── Auto-connect on startup using env vars ─────────────────
    observe({
      refresh_content()
    }) |> shiny::bindEvent(TRUE, once = TRUE)

    # ── Refresh content button ─────────────────────────────────
    observeEvent(input$btn_refresh_content, {
      updateSelectInput(session, "content_picker", choices = c("Refreshing..." = ""))
      updateSelectInput(session, "job_picker", choices = c("Select content first..." = ""))
      jobs_list(NULL)
      parsed_logs(NULL)
      refresh_content()
    })

    # ── Connection status badge ────────────────────────────────
    output$connection_status <- renderUI({
      if (connected()) {
        div(
          class = "connection-status connected",
          icon("circle-check"), "Connected"
        )
      } else {
        div(
          class = "connection-status disconnected",
          icon("circle-xmark"), "Not connected"
        )
      }
    })

    # ── Content selected → fetch jobs ──────────────────────────
    observeEvent(input$content_picker, {
      req(input$content_picker, client())

      # Reset job picker and clear stale logs immediately
      updateSelectInput(session, "job_picker", choices = c("Loading jobs..." = ""))
      jobs_list(NULL)
      parsed_logs(NULL)

      tryCatch({
        jl <- list_jobs(client(), input$content_picker)
        jobs_list(jl)

        if (length(jl) == 0) {
          updateSelectInput(session, "job_picker", choices = c("No jobs found" = ""))
          return()
        }

        # Build labels from job metadata
        job_labels <- vapply(seq_along(jl), function(i) {
          j <- jl[[i]]

          # Friendly tag
          tag <- if (is.null(j$tag)) "run" else j$tag

          # Friendly date
          date_str <- if (is.null(j$start_time)) {
            "unknown date"
          } else {
            # Try explicit ISO8601 parsing first
            time_obj <- as.POSIXct(j$start_time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
            # Fallback to default if that fails
            if (is.na(time_obj)) time_obj <- as.POSIXct(j$start_time)
            
            # Format: 'Feb 13, 14:30' - converts to local time if intended, or keeps UTC if attributes set
            # Actually format() on a POSIXct uses the tz attribute. 
            # If we want local time displayed, we might want to convert or just show UTC.
            # For now, let's stick to the resulting object's timezone (UTC).
            format(time_obj, "%b %d, %H:%M")
          }

          paste0("#", i, "  \U00B7  ", tag, "  \U00B7  ", date_str)
        }, character(1))

        choices <- stats::setNames(seq_along(jl), job_labels)
        updateSelectInput(session, "job_picker", choices = choices)
      }, error = function(e) {
        showNotification(
          paste("Failed to load jobs:", conditionMessage(e)),
          type = "error",
          duration = 5
        )
      })
    })

    # ── Fetch logs ─────────────────────────────────────────────
    observeEvent(input$btn_fetch, {
      req(input$job_picker, jobs_list())
      tryCatch({
        idx <- as.integer(input$job_picker)
        job <- jobs_list()[[idx]]
        raw_log <- fetch_log(job)
        parsed <- parse_log(raw_log)
        parsed_logs(parsed)
        showNotification(
          paste("Loaded", nrow(parsed), "log lines"),
          type = "message",
          duration = 3
        )
      }, error = function(e) {
        showNotification(
          paste("Failed to fetch logs:", conditionMessage(e)),
          type = "error",
          duration = 5
        )
      })
    })

    # Return parsed logs as a reactive for log_viewer to consume
    reactive({ parsed_logs() })
  })
}
