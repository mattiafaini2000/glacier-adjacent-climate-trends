# Relative input paths may use an external, read-only data root. Outputs remain
# under the repository root; existing parent directories are resolved as well.
is_absolute_path <- function(path) {
  grepl("^(/|[A-Za-z]:|\\\\)", path)
}

relative_path_parts <- function(path) {
  if (length(path) != 1L || is.na(path) || !nzchar(path) ||
      is_absolute_path(path)) {
    stop("Expected one non-empty relative path.")
  }
  parts <- strsplit(gsub("\\\\", "/", path), "/", fixed = TRUE)[[1L]]
  if (any(parts %in% c("..", ""))) stop("Path contains an empty or parent component.")
  parts
}

path_is_within <- function(path, root) {
  if (.Platform$OS.type == "windows") {
    path <- tolower(path)
    root <- tolower(root)
  }
  identical(path, root) || startsWith(path, paste0(root, "/"))
}

# Resolve an existing ancestor before allowing a write into a new directory.
check_output_path <- function(path, project_root = getwd()) {
  root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)
  candidate <- gsub("\\\\", "/", path)
  if (!is_absolute_path(candidate)) candidate <- file.path(root, candidate)
  if (any(strsplit(candidate, "/", fixed = TRUE)[[1L]] == "..")) {
    stop("Output paths must not contain parent components.")
  }
  ancestor <- candidate
  suffix <- character()
  while (!file.exists(ancestor) && !dir.exists(ancestor)) {
    suffix <- c(basename(ancestor), suffix)
    parent <- dirname(ancestor)
    if (identical(parent, ancestor)) stop("Cannot resolve output directory.")
    ancestor <- parent
  }
  ancestor <- normalizePath(ancestor, winslash = "/", mustWork = TRUE)
  resolved <- if (length(suffix)) {
    do.call(file.path, as.list(c(ancestor, suffix)))
  } else ancestor
  if (!path_is_within(resolved, root)) stop("Output must stay inside the project.")
  resolved
}

resolve_input_path <- function(data_root, relative) {
  parts <- relative_path_parts(relative)
  root <- normalizePath(data_root, winslash = "/", mustWork = TRUE)
  do.call(file.path, as.list(c(root, parts)))
}

resolve_output_path <- function(project_root, relative) {
  relative_path_parts(relative)
  check_output_path(file.path(project_root, relative), project_root)
}

# Write a result table without R row names. Scientific rounding belongs to the
# calculation that produces the table, rather than to this file writer.
write_csv <- function(data, path, project_root = getwd()) {
  path <- check_output_path(path, project_root)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(data, path, row.names = FALSE, na = "")
  invisible(path)
}

# Called explicitly by entry points, never when a module is sourced.
configure_project_temp <- function(project_root = getwd()) {
  directory <- resolve_output_path(project_root, ".cache/tmp")
  dir.create(directory, recursive = TRUE, showWarnings = FALSE)
  Sys.setenv(TMPDIR = directory, TMP = directory, TEMP = directory)
  invisible(directory)
}
