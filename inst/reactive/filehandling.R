# observes if a new tbl csv is chosen by user
shiny::observe({
  # - - - -
  if(is.null(input$custom_db)) return() # if nothing is chosen, do nothing
  db_path <- input$custom_db$datapath
  preview <- data.table::fread(db_path, header = T, nrows = 3)
  output$db_example <- DT::renderDataTable({
    DT::datatable(data = preview,
    options = list(searching = FALSE,
                   paging = FALSE,
                   info = FALSE))
  })

})

# observes if a new taskbar image is chosen by user
shiny::observe({
  # - - - -
  if(is.null(input$custom_db_img_path)) return() # if nothing is chosen, do nothing
  img_path <- input$custom_db_img_path$datapath
  new_path <- file.path(getwd(), "www", basename(img_path)) # set path to copy to
  gbl$paths$custom.db.path <<- new_path
  # copy image to the www folder
  if(img_path != new_path) file.copy(img_path, new_path, overwrite = T)
  # - - -
  # render taskbar image preview
  output$custom_db_img <- shiny::renderImage({
    list(src = new_path,
         style = "background-image:linear-gradient(0deg, transparent 50%, #aaa 50%),linear-gradient(90deg, #aaa 50%, #ccc 50%);background-size:10px 10px,10px 10px;")
  }, deleteFile = FALSE)
})

# observes if a new taskbar image is chosen by user
shiny::observe({
  if(is.null(input$taskbar_image_path)) return() # if nothing is chosen, do nothing
  img_path <- input$taskbar_image_path$datapath
  new_path <- file.path(getwd(), "www", basename(img_path)) # set path to copy to

  # copy image to the www folder
  if(img_path != new_path) file.copy(img_path, new_path, overwrite = T)

  # render taskbar image preview
  output$taskbar_image <- shiny::renderImage({
    list(src = new_path,
         style = "background-image:linear-gradient(0deg, transparent 50%, #aaa 50%),linear-gradient(90deg, #aaa 50%, #ccc 50%);background-size:10px 10px,10px 10px;")
  }, deleteFile = FALSE)
  
  # change chosen taskbar image in user option file
  MetaboShiny::setOption(lcl$paths$opt.loc,
            key='taskbar_image',
            value=basename(new_path))
})

# observes if user is choosing a different database storage folder
observe({
  # trigger window
  shinyFiles::shinyDirChoose(input, "get_db_dir",
                 roots = gbl$paths$volumes,
                 session = session)

  if(typeof(input$get_db_dir) != "list") return() # if nothing selected or done, ignore

  # parse the file path given based on the possible base folders (defined in global)
  given_dir <- shinyFiles::parseDirPath(gbl$paths$volumes,
                            input$get_db_dir)

  if(is.null(given_dir)) return()
  # change db storage directory in user options file
  MetaboShiny::setOption(lcl$paths$opt.loc, key="db_dir", value=given_dir)

  # render current db location in text
  output$curr_db_dir <- shiny::renderText({getOptions(lcl$paths$opt.loc)$db_dir})
})

# see above, but for working directory. CSV/DB files with user data are stored here.
shiny::observe({
  shinyFiles::shinyDirChoose(input, "get_work_dir",
                 roots = gbl$paths$volumes,
                 session = session)

  if(typeof(input$get_work_dir) != "list") return()

  given_dir <- shinyFiles::parseDirPath(gbl$paths$volumes,
                            input$get_work_dir)
  if(is.null(given_dir)) return()
  MetaboShiny::setOption(lcl$paths$opt.loc,key="work_dir", value=given_dir)
  lcl$paths$work_dir <<- given_dir
  output$curr_exp_dir <- shiny::renderText({MetaboShiny::getOptions(lcl$paths$opt.loc)$work_dir})
})

# triggers if user changes their current project name
observeEvent(input$set_proj_name, {
  proj_name <<- input$proj_name
  if(proj_name == "") return(NULL) # if empty, ignore
  # change path of current db in global
  # change project name in user options file
  MetaboShiny::setOption(lcl$paths$opt.loc, key="proj_name", value=proj_name)
  # print the changed name in the UI
  lcl$proj_name <<- proj_name
  output$proj_name <<- shiny::renderText(proj_name)
  # change path CSV should be / is saved to in session
  lcl$paths$proj_dir <<- file.path(lcl$paths$work_dir, lcl$proj_name)
  lcl$paths$patdb <<- file.path(lcl$paths$proj_dir, paste0(lcl$proj_name,".db"))
  lcl$paths$csv_loc <<- file.path(lcl$paths$proj_dir, paste0(lcl$proj_name,".csv"))
})



observe({
  if(filemanager$do == "load"){
    fn <- paste0(tools::file_path_sans_ext(lcl$paths$csv_loc), ".metshi")
    shiny::showNotification(paste0("Loading existing file: ", basename(fn)))
    if(file.exists(fn)){
      mSet <- NULL
      mSet <- tryCatch({
        load(fn)
        if(is.list(mSet)){
          msg = "Old save selected! Conversion isn't possible due to some batch correction methods changing in R 4.0. Please re-normalize your data."
          metshiAlert(msg)
          NULL
          # # fix orig file
          # orig_fn <- paste0(tools::file_path_sans_ext(lcl$paths$csv_loc), "_ORIG.metshi")
          # mSet_old <- readRDS(orig_fn)
          # names(mSet_old) <- c("dataSet", "analSet", "settings")
          # anal.type <<- "stat"
          # mSet_old <- MetaboAnalystR::Read.TextData(mSet_old,
          #                                           filePath = lcl$paths$csv_loc,
          #                                           "rowu",
          #                                           lbl.type = "disc")  # rows contain samples
          # 
          # mSet_old$dataSet$missing <- is.na(mSet$dataSet$orig)
          # mSet_old$dataSet$start <- mSet$dataSet$orig
          # mSet_old$metshiParams <- mSet$metshiParams
          # mSet_old$metshiParams$rf_norm_parallelize <- "no"
          # mSet_old$metshiParams$rf_norm_ntree <- 5
          # mSet_old$metshiParams$max.allow <- 5000
          # mSet_old$metshiParams$orig.count <- nrow(mSet_old$dataSet$orig)
          # mSet_old$metshiParams$miss_perc <- mSet_old$metshiParams$perc_limit
          # mSet_old$metshiParams$batch_method_a <- "WaveICA"
        }else{
          stop()
        }
      },
      error = function(cond){
        tryCatch({
          mSet <- qs::qread(fn)
        },
        error = function(cond){
          metshiAlert("Corrupt save detected! Reverting to previous state...")
          fn_bu <- normalizePath(paste0(tools::file_path_sans_ext(lcl$paths$csv_loc), 
                                        "_BACKUP.metshi"),mustWork = F)
          fn <- normalizePath(paste0(tools::file_path_sans_ext(lcl$paths$csv_loc), 
                                     ".metshi"))
          file.rename(fn_bu, fn)
          mSet <- qs::qread(fn)
        })
      })
      if(!is.null(mSet)){
        mSet$mSet <- NULL
        mSet$dataSet$combined.method <- TRUE # FC fix
        mSet <<- mSet
        opts <- MetaboShiny::getOptions(lcl$paths$opt.loc)
        lcl$proj_name <<- opts$proj_name
        lcl$paths$proj_dir <<- file.path(lcl$paths$work_dir, lcl$proj_name)
        lcl$paths$patdb <<- file.path(lcl$paths$proj_dir, paste0(opts$proj_name, ".db"))
        lcl$paths$csv_loc <<- file.path(lcl$paths$proj_dir, paste0(opts$proj_name, ".csv"))
        
        shiny::updateCheckboxInput(session,
                                   "paired",
                                   value = mSet$dataSet$paired)
        
        uimanager$refresh <- c("general","statspicker",if("adducts" %in% names(opts)) "adds" else NULL, "ml")
        plotmanager$make <- "general"  
      }
    }
  }else if(filemanager$do == "save"){
    fn <- paste0(tools::file_path_sans_ext(lcl$paths$csv_loc), ".metshi")
    
    if(!is.null(mSet)){
      
      mSet$mSet <- NULL
      fn_bu <- normalizePath(paste0(tools::file_path_sans_ext(lcl$paths$csv_loc), 
                                    "_BACKUP.metshi"),mustWork = F)
      fn <- normalizePath(paste0(tools::file_path_sans_ext(lcl$paths$csv_loc), 
                                 ".metshi"))
      file.rename(fn, fn_bu)
      success = F
      
      try({
        qs::qsave(mSet, file = fn)
        success = T
      })
      
      if(!success){
        file.rename(from = fn_bu, 
                    to = fn)
      }else{
        save_info$prev_time <- Sys.time()
        save_info$has_changed <- FALSE
        
        file.remove(fn_bu)
      }
    } 
  }
  filemanager$do <- "nothing"
})

# "minutes ago saved"
save_info = shiny::reactiveValues(prev_time = c(),
                                  now_time = c(),
                                  has_changed = FALSE)

output$last_saved = shiny::renderText({
  timeStart <- save_info$prev_time
  if(length(timeStart) > 0){
    timeEnd <- save_info$now_time
    difference <- difftime(timeEnd, timeStart, units='mins')
    round.min = round(as.numeric(difference),digits = 0)
    paste("saved", round.min, "min. ago")   
  }else{
    "no save since startup"
  }
})

observe({
  # Re-execute this reactive expression after 1000 milliseconds
  invalidateLater(60000, session)
  if(length(save_info$prev_time) > 0){
    save_info$now_time <- Sys.time()
  }
})

observe({
  # Re-execute this reactive expression after 1000 milliseconds
  invalidateLater(600000, session)
  if(isolate(save_info$has_changed)){
    shiny::showNotification("Autosaving...")
    filemanager$do <- "save"  
  }
})

output$has_unsaved_changes <- shiny::renderUI({
  if(save_info$has_changed){
    shinyBS::tipify(icon("exclamation-triangle"),title = "you have unsaved changes",placement = "top")
  }else{
    ""
  }
})
