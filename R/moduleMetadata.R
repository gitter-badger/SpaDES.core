#' Parse and extract module metadata
#'
#' @inheritParams spades
#'
#' @param module Character string. Your module's name.
#'
#' @param path   Character string specifying the file path to modules directory.
#'               Default is to use the \code{spades.modulePath} option.
#'
#' @return A list of module metadata, matching the structure in
#'         \code{\link{defineModule}}.
#'
#' @author Alex Chubaty
#' @export
#' @include simulation-simInit.R
#' @rdname moduleMetadata
#' @seealso \code{\link{defineModule}}
#'
#' @example inst/examples/example_moduleMetadata.R
#'
setGeneric("moduleMetadata", function(sim, module, path) {
  standardGeneric("moduleMetadata")
})

#' @export
#' @rdname moduleMetadata
setMethod(
  "moduleMetadata",
  signature = c(sim = "missing", module = "character", path = "character"),
  definition = function(module, path) {
    filename <- paste(path, "/", module, "/", module, ".R", sep = "")
    if (!file.exists(filename)) {
      stop(paste(filename, "does not exist. This was created by putting",
                 "modulePath with the module name as a folder and filename. ",
                 "Please correct the modulePath or module name in",
                 "the simInit() call."))
    }

    ## store metadata as list

    defineModuleListItems <- c(
      "name", "description", "keywords", "childModules", "authors",
      "version", "spatialExtent", "timeframe", "timeunit", "citation",
      "documentation", "reqdPkgs", "parameters", "inputObjects", "outputObjects"
    )
    metadata <- lapply(defineModuleListItems, function(xx) {
      pmp <- .parseModulePartial(filename = file.path(path, module, paste0(module, ".R")),
                                 defineModuleElement = xx)
      out2 <- suppressMessages(try(eval(pmp), silent = TRUE))
      if (is(out2, "try-error")) {
        inner2 <- lapply(pmp, function(yyy) {
          # pmp is whole rbind statement
          out4 <- try(eval(yyy), silent = TRUE)
          if (is(out4, "try-error")) {
            yyy <- lapply(yyy, function(yyyyy) {
              # yyy is whole defineParameter statement
              out5 <- try(eval(yyyyy), silent = TRUE)
              if (is(out5, "try-error")) yyyyy <- deparse(yyyyy)
              return(yyyyy)
            })
          }
          if (is.list(yyy)) yyy <- as.call(yyy)
          return(yyy)
        })

        out2 <- as.call(inner2)
      }
      # Remove extra spaces
      aa <- capture.output(type = "message", {bb <- eval(out2)})
      return(bb)
    })

    names(metadata) <- defineModuleListItems

    #metadata <- eval(parse(text = x)) # can't be used because can't evaluate start(sim)

    metadata <- rmExtraSpacesEOLList(metadata)
    return(metadata)
})

#' @export
#' @rdname moduleMetadata
setMethod(
  "moduleMetadata",
  signature = c(sim = "missing", module = "character", path = "missing"),
  definition = function(module) {
    moduleMetadata(module = module, path = getOption("spades.modulePath"))
})

#' @export
#' @rdname moduleMetadata
setMethod(
  "moduleMetadata",
  signature = c(sim = "ANY", module = "ANY", path = "ANY"),
  definition = function(sim, module, path) {
    if (is.character(sim)) {
      message("Assuming sim is a module name")
      if (missing(path)) {
        metadataList <- moduleMetadata(module = sim)
      } else {
        metadataList <- moduleMetadata(module = sim, path = path)
      }

    } else {

      if (!missing(path)) message("path not used with sim provided")
      if (missing(module)) {
        module <- unlist(modules(sim))
      }
      numModules <- length(module)

      metadata <- sim@depends@dependencies[module]
      sn <- slotNames(".moduleDeps")
      names(sn) <- sn
      metadataList <- lapply(metadata, function(mod) {
        lapply(sn, function(element) {
          slot(mod, name = element)
        })
      })
      metadataList <- lapply(metadataList, function(moduleMetadata) {
        rmExtraSpacesEOLList(moduleMetadata)
      })
      if (numModules == 1)
        metadataList <- metadataList[[module]]
    }

    return(metadataList)
})

################################################################################
#' Parse and extract a module's version
#'
#' @param module Character string. Your module's name.
#'
#' @param path   Character string specifying the file path to modules directory.
#'               Default is to use the \code{spades.modulePath} option.
#'
#' @inheritParams spades
#' @inheritParams .parseModulePartial
#'
#' @return \code{numeric_version} indicating the module's version.
#'
#' @author Alex Chubaty
#' @export
#' @include simulation-simInit.R
#' @rdname moduleVersion
#' @seealso \code{\link{moduleMetadata}}
#'
#' @example inst/examples/example_moduleVersion.R
#'
setGeneric("moduleVersion", function(module, path, sim, envir = NULL) {
  standardGeneric("moduleVersion")
})

#' @export
#' @rdname moduleVersion
setMethod(
  "moduleVersion",
  signature = c(module = "character", path = "character", sim = "missing", envir = "ANY"),
  definition = function(module, path, envir) {
    v <- .parseModulePartial(filename = file.path(path, module, paste0(module, ".R")),
                             defineModuleElement = "version", envir = envir)
    if (is.null(names(v))) {
      as.numeric_version(v) ## SpaDES < 1.3.1.9044
    } else {
      as.numeric_version(v[[module]]) ## SpaDES >= 1.3.1.9044
    }
})

#' @export
#' @rdname moduleVersion
setMethod(
  "moduleVersion",
  signature = c(module = "character", path = "missing", sim = "missing", envir = "ANY"),
  definition = function(module, envir) {
    moduleVersion(module = module, path = getOption("spades.modulePath"), envir = envir)
})

#' @export
#' @rdname moduleVersion
setMethod(
  "moduleVersion",
  signature = c(module = "character", path = "missing", sim = "simList", envir = "ANY"),
  definition = function(module, sim, envir) {
    v <- .parseModulePartial(sim = sim, modules = list(module),
                             defineModuleElement = "version", envir = envir) %>%
      `[[`(module)

    if (is.null(names(v))) {
      as.numeric_version(v) ## SpaDES < 1.3.1.9044
    } else {
      as.numeric_version(v[[module]])  ## SpaDES >= 1.3.1.9044
    }
})

################################################################################
#' Extract a module's parameters, inputs, or outputs
#'
#' These are more or less wrappers around \code{moduleMetadata}, with the exception
#' that extraneous spaces and End-Of-Line characters will be removed from the
#' \code{desc} arguments in \code{defineParameters}, \code{defineInputs}, and
#' \code{defineOutputs}
#'
#' @param module Character string. Your module's name.
#'
#' @param path   Character string specifying the file path to modules directory.
#'               Default is to use the \code{spades.modulePath} option.
#'
#' @return \code{data.frame}
#'
#' @author Alex Chubaty
#' @export
#' @rdname moduleParamsInputsOuputs
#' @seealso \code{\link{moduleMetadata}}
#'
#' @example inst/examples/example_moduleParamsInputsOuputs.R
#'
setGeneric("moduleParams", function(module, path) {
  standardGeneric("moduleParams")
})

#' @export
#' @rdname moduleParamsInputsOuputs
setMethod(
  "moduleParams",
  signature = c(module = "character", path = "character"),
  definition = function(module, path) {
    md <- suppressWarnings(moduleMetadata(module = module, path = path))
    # remove spaces and EOL
    md[["parameters"]][["paramDesc"]] <- rmExtraSpacesEOL(md[["parameters"]][["paramDesc"]])
    md[["parameters"]]
})

#' @export
#' @rdname moduleParamsInputsOuputs
setGeneric("moduleInputs", function(module, path) {
  standardGeneric("moduleInputs")
})

#' @export
#' @rdname moduleParamsInputsOuputs
setMethod(
  "moduleInputs",
  signature = c(module = "character", path = "character"),
  definition = function(module, path) {
    md <- suppressWarnings(moduleMetadata(module = module, path = path))
    # remove spaces and EOL
    md[["inputObjects"]][["desc"]] <- rmExtraSpacesEOL(md[["inputObjects"]][["desc"]])
    md[["inputObjects"]]
})

#' @export
#' @rdname moduleParamsInputsOuputs
setGeneric("moduleOutputs", function(module, path) {
  standardGeneric("moduleOutputs")
})

#' @export
#' @rdname moduleParamsInputsOuputs
setMethod(
  "moduleOutputs",
  signature = c(module = "character", path = "character"),
  definition = function(module, path) {
    md <- suppressWarnings(moduleMetadata(module = module, path = path))
    # remove spaces and EOL
    md[["outputObjects"]][["desc"]] <- rmExtraSpacesEOL(md[["outputObjects"]][["desc"]])
    md[["outputObjects"]]
})

rmExtraSpacesEOL <- function(x) gsub(" +|[ *\n]+", " ", x)

rmExtraSpacesEOLList <- function(xx) {
  toRmESEOL <- grepl(c("parameters|inputObjects|outputObjects"), names(xx))
  xx[toRmESEOL] <- lapply(xx[toRmESEOL], function(elem) {
    if (any(grepl("desc", tolower(names(elem))))) {
      whCol <- grep("desc", tolower(names(elem)))
      elem[[whCol]] <- rmExtraSpacesEOL(elem[[whCol]])
      elem
    } else {
      elem
    }
  })

  xx
}
