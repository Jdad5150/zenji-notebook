# Zenji notebook R kernel worker.
# Same JSON protocol as the Python worker.

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  lib <- Sys.getenv("R_LIBS_USER")
  if (lib == "") lib <- file.path(Sys.getenv("HOME"), "R", "library")
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  install.packages("jsonlite", lib = lib, repos = "https://cloud.r-project.org", quiet = TRUE)
  .libPaths(c(lib, .libPaths()))
}

if (!requireNamespace("base64enc", quietly = TRUE)) {
  lib <- Sys.getenv("R_LIBS_USER")
  if (lib == "") lib <- file.path(Sys.getenv("HOME"), "R", "library")
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  install.packages("base64enc", lib = lib, repos = "https://cloud.r-project.org", quiet = TRUE)
  .libPaths(c(lib, .libPaths()))
}

library(jsonlite)
library(base64enc)

# Global environment for persistent variables across cells
.zenji_env <- new.env(parent = globalenv())

execute <- function(code) {
  # Open a PNG device before execution so any plot() call writes to it
  tmp <- tempfile(fileext = ".png")
  png(tmp, width = 800, height = 600)

  stdout_con <- textConnection("stdout_lines", open = "w", local = TRUE)
  stderr_lines <- character(0)

  sink(stdout_con, type = "output")
  withCallingHandlers(
    tryCatch(
      {
        exprs <- parse(text = code)
        for (i in seq_along(exprs)) {
          val <- withVisible(eval(exprs[[i]], envir = .zenji_env))
          if (i == length(exprs) && val$visible) {
            print(val$value)
          }
        }
      },
      error = function(e) {
        stderr_lines <<- c(stderr_lines, conditionMessage(e))
      }
    ),
    warning = function(w) {
      stderr_lines <<- c(stderr_lines, paste("Warning:", conditionMessage(w)))
      invokeRestart("muffleWarning")
    },
    message = function(m) {
      stderr_lines <<- c(stderr_lines, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  sink(type = "output")
  close(stdout_con)

  # Always close the PNG device
  dev.off()

  # Only include figure if something was actually drawn (file has content)
  figs <- list()
  if (file.exists(tmp) && file.info(tmp)$size > 0) {
    raw <- readBin(tmp, "raw", file.info(tmp)$size)
    encoded <- base64enc::base64encode(raw)
    if (!is.null(encoded) && nchar(encoded) > 0) {
      figs <- list(encoded)
    }
  }
  unlink(tmp)

  list(
    stdout = paste(stdout_lines, collapse = "\n"),
    stderr = paste(stderr_lines, collapse = "\n"),
    figures = figs
  )
}

classify <- function(val) {
  tryCatch({
    cls <- class(val)[1]
    if (cls %in% c('data.frame', 'tbl_df', 'tbl', 'tibble')) {
      return(list(kind = 'dataframe', shape = paste0(nrow(val), ' × ', ncol(val))))
    }
    d <- dim(val)
    if (!is.null(d) && length(d) == 2) {
      return(list(kind = 'matrix', shape = paste0(d[1], ' × ', d[2])))
    }
    if (!is.null(d) && length(d) > 2) {
      return(list(kind = 'tensor', shape = paste(d, collapse = '×')))
    }
    if (is.function(val)) {
      return(list(kind = 'function', shape = NA_character_))
    }
    n <- length(val)
    if (cls %in% c('numeric', 'integer', 'double', 'complex', 'logical') && n == 1) {
      return(list(kind = 'scalar', shape = NA_character_))
    }
    if (cls == 'character' && n == 1) {
      return(list(kind = 'string', shape = NA_character_))
    }
    if (cls == 'list') {
      return(list(kind = 'mapping', shape = as.character(n)))
    }
    return(list(kind = 'sequence', shape = as.character(n)))
  }, error = function(e) {
    list(kind = 'other', shape = NA_character_)
  })
}

get_variables <- function() {
  vars <- ls(.zenji_env)
  result <- lapply(vars, function(name) {
    val <- get(name, envir = .zenji_env)
    cl <- classify(val)
    val_str <- tryCatch({
      s <- paste(capture.output(print(val)), collapse = "\n")
      if (nchar(s) > 300) paste0(substr(s, 1, 300), "…") else s
    }, error = function(e) "<error>")
    list(
      name  = name,
      value = val_str,
      type  = class(val)[1],
      kind  = cl$kind,
      shape = cl$shape
    )
  })
  list(variables = result)
}

get_modules <- function() {
  pkgs <- search()
  pkgs <- pkgs[grepl("^package:", pkgs)]
  result <- lapply(pkgs, function(p) {
    name <- sub("^package:", "", p)
    path <- tryCatch(find.package(name), error = function(e) "built-in")
    list(name = name, path = path)
  })
  list(modules = result)
}

# Main loop
con <- file("stdin", open = "r", blocking = TRUE)
repeat {
  line <- tryCatch(readLines(con, n = 1, warn = FALSE), error = function(e) character(0))
  if (length(line) == 0) break
  line <- trimws(line)
  if (nchar(line) == 0) next

  msg <- tryCatch(fromJSON(line, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(msg)) next

  resp <- switch(msg$cmd,
    execute   = execute(msg$code),
    variables = get_variables(),
    modules   = get_modules(),
    quit      = { close(con); quit(save = "no") },
    list(error = paste("unknown cmd:", msg$cmd))
  )

  cat(toJSON(resp, auto_unbox = TRUE), "\n", sep = "")
  flush(stdout())
}
