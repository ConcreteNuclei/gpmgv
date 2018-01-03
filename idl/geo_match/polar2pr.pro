;===============================================================================
;+
; Copyright © 2008, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; polar2pr.pro          Morris/SAIC/GPM_GV      September 2008
;
; DESCRIPTION
; -----------
; Performs a resampling of PR and GV data to common 3-D volumes, as defined in
; the horizontal by the location of PR rays, and in the vertical by the heights
; of the intersection of the PR rays with the top and bottom edges of individual
; elevation sweeps of a ground radar scanning in PPI mode.  The data domain is
; determined by the location of the ground radars overpassed by the PR swath,
; and by the cutoff range (range_threshold_km) which is a mandatory parameter
; for this procedure.  The PR and GV (ground radar) files to be processed are
; specified in the control_file, which is a mandatory parameter containing the
; fully-qualified file name of the control file to be used in the run.  Optional
; parameters (PR_ROOT and DIRxx) allow for non-default local paths to the PR and
; GV files whose partial pathnames are listed in the control file.  The defaults
; for these paths are as specified in the environs.inc file.  All file path
; optional parameter values must begin with a leading slash (e.g., '/mydata')
; and be enclosed in quotes, as shown.  Optional binary keyword parameters
; control immediate output of PR-GV reflectivity differences (/SCORES), plotting
; of the matched PR and GV reflectivity fields sweep-by-sweep in the form of
; PPIs on a map background (/PLOT_PPIS), and plotting of the matching PR and GV
; bin horizontal outlines (/PLOT_BINS) for the common 3-D volume.
;
; The control file is of a specific layout and contains specific fields in a
; fixed order and format.  See the script "doGeoMatch4SelectCases.sh", which
; creates the control file and invokes IDL to run this procedure.  Completed
; PR and GV matchup data for an individual site overpass event (i.e., a given
; TRMM orbit and ground radar site) are written to a netCDF file.  The size of
; the dimensions in the data fields in the netCDF file vary from one case to
; another, depending on the number of elevation sweeps in the GV radar volume
; scan and the number of PR footprints within the cutoff range from the GV site.
;
; The optional parameter NC_FILE specifies the directory to which the output
; netCDF files will be written.  It is created if it does not yet exist.  Its
; default value is derived from the variables NCGRIDS_ROOT+GEO_MATCH_NCDIR as
; specified in the environs.inc file.  If the binary parameter FLAT_NCPATH is
; set then the output netCDF files are written directly under the NC_FILE
; directory (legacy behavior).  Otherwise a hierarchical subdirectory tree is
; (as needed) created under the NC_FILE directory, of the form:
;     TRMM/PR/PPS_VERSION/MATCHUP_VERSION/YEAR
; and the output netCDF files are written to this subdirectory.  The TRMM and
; PR subdirectory names are literal values "TRMM" and "PR", where the other path
; components are determined in this procedure.
;
; An optional parameter (NC_NAME_ADD) specifies a component to be added to the
; output netCDF file name, to specify uniqueness in the case where more than
; one version of input data are used, a different range threshold is used, etc.
;
; NOTE: THE SET OF CODE CONTAINED IN THIS FILE IS NOT THE COMPLETE POLAR2PR
;       PROCEDURE.  THE REMAINING CODE IN THE FULL PROCEDURE IS CONTAINED IN
;       THE FILE "polar2pr_resampling.pro", WHICH IS INCORPORATED INTO THIS
;       FILE/PROCEDURE BY THE IDL "include" MECHANISM.
;
;
; MODULES
; -------
;   1) FUNCTION  plot_bins_bailout
;   2) PROCEDURE polar2pr
;
;
; EXTERNAL LIBRARIES
; ------------------
; Selected IDL procedures and functions of the RSL_IN_IDL library, Version 1.3.9
; or later, are required to compile and run this procedure.  This library may be
; obtained from the TRMM GV web site at http://trmm-fc.gsfc.nasa.gov/index.html
;
;
; CONSTRAINTS
; -----------
; PR: 1) Only PR Versions 6 and 7, or other PR versions with HDF files in PR
;        Version 6's or 7's format, are supported by this code.
; GV: 1) Only radar data files in Universal Format (UF) are supported by this
;        code, although radar files in other formats supported by the TRMM Radar
;        Software Library (RSL) may work, depending on constraint 2, below.
;     2) UF files for sites not 'known' to this code must label their quality-
;        controlled reflectivity data field name as 'CZ'.  This constraint is
;        implemented in the function common_utils/get_site_specific_z_volume.pro
;
;
; HISTORY
; -------
; 9/2008 by Bob Morris, GPM GV (SAIC)
;  - Created.
; 10/2008 by Bob Morris, GPM GV (SAIC)
;  - Implemented selective PR footprint LUT/averages generation
; 10/17/2008 by Bob Morris, GPM GV (SAIC)
;  - Added call to new function UNIQ_SWEEPS to improve removal of duplicate
;    sweeps at (nominally) the same elevation
; 10/20/2008 by Bob Morris, GPM GV (SAIC)
;  - Added spawned command to gzip the output netCDF file after writing
;  - Changed the PR dBZ threshold (PR_DBZ_MIN) from 15.0 to 18.0
; 1/6/2009 by Bob Morris, GPM GV (SAIC)
;  - Added optional parameter NC_NAME_ADD to be added to the output netCDF
;    file name generated within this procedure, to allow more than one version
;    of matchup data to exist without conflicting filenames.  Needed this for
;    KWAJ data processing, where a second set of GV data was provided.
; 2/6/2009 by Bob Morris, GPM GV (SAIC)
;  - Small in-line documentation enhancements
; 6/15/2009 by Bob Morris, GPM GV (SAIC)
;  - Added NC_DIR parameter to the optional keywords, to specify the output
;    file path for the netCDF files.  Generates a fully-qualified netCDF file
;    name using this path, for the call to gen_geo_match_netcdf() function.
;  - Use value in environs.inc for dafault common path to UF files, and put a
;    '/' after this path when used to build the UF file pathname.  All rel/abs
;    file path parameters are now consistent in requiring a leading '/'
; 6/16/2010 by Bob Morris, GPM GV (SAIC)
;  - Added MARK_EDGES parameter to make addition of 'bogus' footprints optional.
;  - Streamlined call to map_proj_forward() to eliminate FOR looping.
; 8/19/2010 by Bob Morris, GPM GV (SAIC)
;  - Added PRINT statements to output the netCDF file name, and added verbose
;    switch to gzip command that follows closing of netCDF output file.
;  - Added WDELETE commands to close PPI windows following netCDF file closure,
;    in the case where PLOT_PPIS keyword option is set.
;  - Moved FUNCTION plot_bins_bailout() to the beginning of the source file to
;    alleviate any compile/run ordering issues.
; 9/10/2010 by Bob Morris, GPM GV (SAIC)
;  - Dealt with 'siteElev' parameter in ground radar lines in control file so
;    that it can be used in code inside polar2pr_resampling.pro
; 9/15/2010 by Bob Morris, GPM GV (SAIC)
;  - Add siteElev to hgt_at_range value in call to get_parallax_dx_dy() to
;    figure parallax shift for height above MSL rather than AGL.
; 10/8/2010 by Bob Morris, GPM GV (SAIC)
;  - Fixed bug in calling read_pr_2b31_fields without first initializing
;    surfRain_2b31 variable, now that read_2b31_file() is used for v6/v7.
; 11/11/10 by Bob Morris, GPM GV (SAIC)
;  - Add 2A23 file to the control file, and to the PR products to be read from.
;  - Add variable 'threeDreflectStdDev' for GR reflectivity, and 'BBstatus'
;    and 'status' for variables extracted from 2A-23 product.
; 11/17/10 by Bob Morris, GPM GV (SAIC)
;  - Reference 'include" file grid_def.inc for DATA_PRESENT, NO_DATA_PRESENT
;    used to assign values for have_xxx variables
; 1/5/11 by Bob Morris, GPM GV (SAIC)
;  - Add keyword parameters PR_DBZ_MIN, DBZ_MIN and PR_RAIN_MIN to allow
;    specification of non-default values for these parameters.
; 2/10/11 by Bob Morris, GPM GV (SAIC)
;  - Added some file name checking logic to the parsing of the PR lines of the
;    control file.
; 3/17/11 by Bob Morris, GPM GV (SAIC)
;  - Added subfields for PR Version and GeoMatch netCDF file version to the
;    "unique" names we generate for the output netCDF files.
;  - Added array of strings to hold PR and GR input filenames to pass to the
;    gen_geo_match_netcdf() function for inclusion as netCDF global attributes
;    in the matchup files, version 2.1.
; 3/22/11 by Bob Morris, GPM GV (SAIC)
;  - Added CASE statement to the parsing of the GV lines of the control file to
;    handle a simplified control file format.  Added a call to a new function,
;    ticks_from_datetime(), to convert ASCII datetime field to unix ticks for
;    the simplified control file case.
;  - Added logic to extract PR_version from the 9th field of the PR lines of
;    the control file, if this field is present.
;  - Added PROCEDURE skip_gr_events to walk over the GR lines in the control
;    file when there is a problem with the PR files, so that the pointer in the
;    control file correctly advances to the next PR line to be read/processed.
; 7/18/13 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR rainrate field from radar data files, when present.
; 1/27/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR HID, D0, and Nw fields from radar data files, when
;    present.
; 2/7/14 by Bob Morris, GPM GV (SAIC)
;  - Added Max and StdDev variables and presence flags for Dzero and Nw fields
;    to the variables computed and written to the netCDF files.
;  - Added capability to pass UF field IDs for GR Z, rainrate, HID, D0, and Nw
;    in a structure as a parameter to gen_geo_match_netcdf().
; 2/11/14 by Bob Morris, GPM GV (SAIC)
;  - Added mean, maximum, and StdDev of Dual-pol variables Zdr, Kdp, and RHOhv,
;    along with their presence flags and UF IDs, for file version 2.3.
; 2/17/14 by Bob Morris, GPM GV (SAIC)
;  - Retrieve special value DR_KD_MISSING from radar_dp_parameters() for
;    assigning Kdp, Zdr in no_echoes situation.
; 04/04/2014 by Bob Morris, GPM GV (SAIC)
;  - Added siteID string as a mandatory parameter for gen_geo_match_netcdf(),
;    since we allow other than 4-character GR site IDs now.
;  - Removed the redundant have_XXX_Max and have_XXX_StdDev variables.
; 07/15/2014 by Bob Morris, GPM GV (SAIC)
;  - Renamed all *GR_DP_* variables to *GR_*, removing the "DP_" designators
;    for file version 3.0.
; 8/7/14 by Bob Morris, GPM GV (SAIC)
;  - Added logic to determine if there is any non-missing GR data for the orbit
;    before trying to read the PR and GR files.  If not, then save time and
;    just skip over the orbit's entries in the control file without reading any
;    data files.
; 02/03/2015 by Bob Morris, GPM GV (SAIC)
;  - Added processing of 2A25 PIA and its presence flag for new version 3.1
;    matchup file.
; 03/02/15 by Bob Morris, GPM GV (SAIC)
;  - Added FLAT_NCPATH parameter to control whether we generate the hierarchical
;    netCDF output file paths (default) or continue to write the netCDF files to
;    the "flat" directory defined by NC_DIR or NCGRIDS_ROOT+GEO_MATCH_NCDIR (if
;    FLAT_NCPATH is set to 1).
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================

FUNCTION plot_bins_bailout
   PRINT, ""
   PRINT, "PLOT_BINS is activated, this is EXTREMELY slow."
   prompt2do = "Disable PLOT_BINS? (enter Y or N): "
   choicenum = 1
   tryagain:
   reply = 'x'
   WHILE (reply NE 'Y' AND reply NE 'N') DO BEGIN
      READ, reply, PROMPT=prompt2do
      IF (reply EQ 'Y' OR reply EQ 'y') THEN reply='Y'
      IF (reply EQ 'N' OR reply EQ 'n') THEN reply='N'
   ENDWHILE
   IF reply EQ 'Y' THEN BEGIN
      PRINT, "PLOT_BINS option disabled.  Good choice."
   ENDIF ELSE BEGIN
      IF choicenum EQ 1 THEN BEGIN
         choicenum = 2
         prompt2do = "Really?  PLOT_BINS is active.  Disable it now? (Y/N):"
         goto, tryagain
      ENDIF
      PRINT, "PLOT_BINS is active.  Good Luck!"
   ENDELSE
   PRINT, ""
   return, reply
END

;*******************************************************************************

PRO skip_gr_events, lun, nsites
   line = ""
   FOR igv=0,nsites-1  DO BEGIN
     ; read and print the control file GV site ID, lat, lon, elev, filename, etc.
      READF, lun, line
      PRINT, igv+1, ": ", line
   ENDFOR
END

;*******************************************************************************

PRO polar2pr, control_file, range_threshold_km, PR_ROOT=prroot, DIR1C=dir1c, $
              DIR23=dir23, DIR2A=dir2a, DIR2B=dir2b, DIRGV=dirgv, SCORES=run_scores, $
              PLOT_PPIS=plot_PPIs, PLOT_BINS=plot_bins, NC_DIR=nc_dir, $
              NC_NAME_ADD=ncnameadd, MARK_EDGES=mark_edges, $
              PR_DBZ_MIN=pr_dbz_min, DBZ_MIN=dBZ_min, PR_RAIN_MIN=pr_rain_min, $
              FLAT_NCPATH=flat_ncpath

IF KEYWORD_SET(plot_bins) THEN BEGIN
   reply = plot_bins_bailout()
   IF reply EQ 'Y' THEN plot_bins = 0
ENDIF

IF N_ELEMENTS( mark_edges ) EQ 1 THEN BEGIN
   IF mark_edges NE 0 THEN mark_edges=1
ENDIF ELSE mark_edges = 0

COMMON sample, start_sample, sample_range, num_range, RAYSPERSCAN

; "Include" file for DATA_PRESENT, NO_DATA_PRESENT
@grid_def.inc
; "Include" file for PR-product-specific parameters (i.e., RAYSPERSCAN):
@pr_params.inc
; "Include" file for names, paths, etc.:
@environs.inc

; set to a constant, in case an obsolete control file format is used
PR_version = 6

; Values for "have_somegridfield" flags: (now defined within grid_def.inc
; via INCLUDE mechanism, and reversed from previous values to align with C and
; IDL True/False interpretation of values 1 and 0)
;DATA_PRESENT = 1
;NO_DATA_PRESENT = 0  ; default fill value, defined in grid_def.inc and used in
                     ; gen_geo_match_netcdf.pro


; ***************************** Local configuration ****************************

   ; where provided, override file path default values from environs.inc:
    in_base_dir =  GVDATA_ROOT ; default root dir for UF files
    IF N_ELEMENTS(dirgv)  EQ 1 THEN in_base_dir = dirgv

    IF N_ELEMENTS(prroot) EQ 1 THEN PRDATA_ROOT = prroot
    IF N_ELEMENTS(dir1c)  EQ 1 THEN DIR_1C21 = dir1c
    IF N_ELEMENTS(dir23)  EQ 1 THEN DIR_2A23 = dir23
    IF N_ELEMENTS(dir2a)  EQ 1 THEN DIR_2A25 = dir2a
    IF N_ELEMENTS(dir2b)  EQ 1 THEN DIR_2B31 = dir2b
    
    IF N_ELEMENTS(nc_dir)  EQ 1 THEN BEGIN
       NCGRIDSOUTDIR = nc_dir
    ENDIF ELSE BEGIN
       NCGRIDSOUTDIR = NCGRIDS_ROOT+GEO_MATCH_NCDIR
    ENDELSE

   ; tally number of reflectivity bins below this dBZ value in PR Z averages
    IF N_ELEMENTS(pr_dbz_min) NE 1 THEN BEGIN
       PR_DBZ_MIN = 18.0
       PRINT, "Assigning default value of 18 dBZ to PR_DBZ_MIN."
    ENDIF
   ; tally number of reflectivity bins below this dBZ value in GR Z averages
    IF N_ELEMENTS(dBZ_min) NE 1 THEN BEGIN
       dBZ_min = 15.0   ; low-end GV cutoff, for now
       PRINT, "Assigning default value of 15 dBZ to DBZ_MIN for ground radar."
    ENDIF
   ; tally number of rain rate bins (mm/h) below this value in PR rr averages
    IF N_ELEMENTS(pr_rain_min) NE 1 THEN BEGIN
       PR_RAIN_MIN = 0.01
       PRINT, "Assigning default value of 0.01 mm/h to PR_RAIN_MIN."
    ENDIF

; ******************************************************************************


; will skip processing PR points beyond this distance from a ground radar
rough_threshold = range_threshold_km * 1.1

; precompute the reuseable ray angle trig variables for parallax:
cos_inc_angle = DBLARR(RAYSPERSCAN)
tan_inc_angle = DBLARR(RAYSPERSCAN)
cos_and_tan_of_pr_angle, cos_inc_angle, tan_inc_angle

; initialize the variables into which file records are read as strings
dataPR = ''
dataGV = ''

; open and process control file, and generate the matchup data for the events

OPENR, lun0, control_file, ERROR=err, /GET_LUN

WHILE NOT (EOF(lun0)) DO BEGIN 

   PRINT, ""
   PRINT, '===================================================================='
   PRINT, ""

  ; get PR filenames and count of GV file pathnames to do for an orbit
  ; - read the '|'-delimited input file record into a single string:
   READF, lun0, dataPR

  ; parse dataPR into its component fields: 1C21 file name, 2A23 file name, 2A25 file name,
  ; 2B31 file name, orbit number, number of sites, YYMMDD, and PR subset
   parsed=STRSPLIT( dataPR, '|', /extract )
   parseoffset = 0
   IF N_ELEMENTS(parsed) GT 7 THEN parseoffset = 1  ; is new control file including 2A23 file name
  ; get filenames as listed in/on the database/disk
   idx21 = WHERE(STRPOS(parsed,'1C21') GE 0, count21)
   if count21 EQ 1 THEN origFile21Name = STRTRIM(parsed[idx21],2) ELSE origFile21Name='no_1C21_file'
   idx23 = WHERE(STRPOS(parsed,'2A23') GE 0, count23)
   if count23 EQ 1 THEN origFile23Name = STRTRIM(parsed[idx23],2) ELSE origFile23Name='no_2A23_file'
   idx25 = WHERE(STRPOS(parsed,'2A25') GE 0, count25)
   if count25 EQ 1 THEN origFile25Name = STRTRIM(parsed[idx25],2) ELSE origFile25Name='no_2A25_file'
   idx31 = WHERE(STRPOS(parsed,'2B31') GE 0, count31)
   if count31 EQ 1 THEN origFile31Name = STRTRIM(parsed[idx31],2) ELSE origFile31Name='no_2B31_file'
   orbit = parsed[3+parseoffset]
   nsites = FIX( parsed[4+parseoffset] )
   IF (nsites LE 0 OR nsites GT 99) THEN BEGIN
      PRINT, "Illegal number of GR sites in control file: ", parsed[4+parseoffset]
      PRINT, "Line: ", dataPR
      PRINT, "Quitting processing."
      GOTO, bailOut
   ENDIF
   IF ( origFile25Name EQ 'no_2A25_file' OR origFile21Name EQ 'no_1C21_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR finding 1C21 and/or 2A-25 product file name(s) in control file: ", control_file
      PRINT, "Line: ", dataPR
      PRINT, "Skipping events for orbit = ", orbit
      skip_gr_events, lun0, nsites
      PRINT, ""
      GOTO, nextOrbit
   ENDIF
   DATESTAMP = parsed[5+parseoffset]      ; in YYMMDD format
   subset = parsed[6+parseoffset]
   IF N_ELEMENTS(parsed) EQ 9 THEN BEGIN
      ; control file includes PR_version
      print, '' & print, "Overriding PR_version with value from control file: ", parsed[8] & print, ''
      PR_version = parsed[8]
   ENDIF
  ; use provided PR_version value in netCDF file name and internal attribute
   prverstr = PR_version

  ; make sure the PR version used in output file path is of format 'V0x', x=6,7,8
   SWITCH PR_version OF
      'V06' :
      'V07' :
      'V08' : break
        '6' :
        '7' :
        '8' : BEGIN
                PR_version = 'V0'+PR_version
                break
              END
       ELSE : message, "Illegal PR_version value in control file."
   ENDSWITCH

  ; set up the date/product-specific output filepath

   matchup_file_version=0.0  ; give it a bogus value, for now
  ; Call gen_geo_match_netcdf with the option to only get current file version
  ; so that it can become part of the matchup file path/name
   throwaway = gen_geo_match_netcdf( GEO_MATCH_VERS=matchup_file_version )

  ; substitute an underscore for the decimal point in matchup_file_version
   verarr=strsplit(string(matchup_file_version,FORMAT='(F0.1)'),'.',/extract)
   verstr=verarr[0]+'_'+verarr[1]

  ; generate the netcdf matchup file path
   IF KEYWORD_SET(flat_ncpath) THEN BEGIN
      NC_OUTDIR = NCGRIDSOUTDIR
   ENDIF ELSE BEGIN
      NC_OUTDIR = NCGRIDSOUTDIR+'/TRMM/PR/'+PR_version+'/'+verstr $
                  +'/20'+STRMID(DATESTAMP, 0, 2)  ; 4-digit Year
   ENDELSE


   dataGVarr = STRARR( nsites )   ; array to store GR-type control file lines
   numUFgood = 0
   FOR igv=0,nsites-1  DO BEGIN
     ; read and parse the control file GR filename to determine which lines
     ; have "actual" GR data file names
     ;  - read each overpassed site's information as a '|'-delimited string
      READF, lun0, dataGV
      dataGVarr[igv] = dataGV      ; write the whole line to the string array
      PRINT, igv+1, ": ", dataGV

     ; parse dataGV to get its 1CUF file pathname, and increment numUFgood
     ; count for each non-missing UF file anme

      parsed=STRSPLIT( dataGV, '|', count=nGRfields, /extract )
      CASE nGRfields OF
        9 : BEGIN   ; legacy control file format
              origUFName = parsed[8]  ; filename as listed in/on the database/disk
              IF file_basename(origUFName) NE 'no_1CUF_file' THEN numUFgood++
            END
        6 : BEGIN   ; streamlined control file format, already have orbit #
              origUFName = parsed[5]  ; filename as listed in/on the database/disk
              IF file_basename(origUFName) NE 'no_1CUF_file' THEN numUFgood++
            END
        ELSE : BEGIN
                 print, ""
                 print, "Incorrect number of GR-type fields in control file:"
                 print, dataGV
                 print, ""
               END
      ENDCASE
   ENDFOR

  ; if there are no good ground radar files, don't even bother reading DPR,
  ; just skip to the next orbit's control file information
   IF numUFgood EQ 0 THEN BEGIN
      PRINT, "No non-missing UF files, skip processing for orbit = ", orbit
      PRINT, ""
      GOTO, nextOrbit
   ENDIF

;  add the well-known (or local) paths to get the fully-qualified file names
   file_1c21 = PRDATA_ROOT+DIR_1C21+"/"+origFile21Name
   file_2a23 = PRDATA_ROOT+DIR_2A23+"/"+origFile23Name
   file_2a25 = PRDATA_ROOT+DIR_2A25+"/"+origFile25Name
   file_2b31 = PRDATA_ROOT+DIR_2B31+"/"+origFile31Name

; store the file basenames in a string array to be passed to gen_geo_match_netcdf()
   infileNameArr = STRARR(5)
   infileNameArr[0] = FILE_BASENAME(origFile21Name)
   infileNameArr[1] = FILE_BASENAME(origFile23Name)
   infileNameArr[2] = FILE_BASENAME(origFile25Name)
   infileNameArr[3] = FILE_BASENAME(origFile31Name)

; initialize PR variables/arrays and read 1C21 fields
   SAMPLE_RANGE=0
   START_SAMPLE=0
   num_range = NUM_RANGE_1C21
   dbz_1c21=FLTARR(sample_range>1,1,num_range)
   landOceanFlag=INTARR(sample_range>1,RAYSPERSCAN)
   binS=INTARR(sample_range>1,RAYSPERSCAN)
   rayStart=INTARR(RAYSPERSCAN)
   status = read_pr_1c21_fields( file_1c21, DBZ=dbz_1c21,       $
                                 OCEANFLAG=landOceanFlag,       $
                                 BinS=binS, RAY_START=rayStart )
   IF ( status NE 0 ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR reading fields from ", file_1c21
      PRINT, "Skipping events for orbit = ", orbit
      skip_gr_events, lun0, nsites
      PRINT, ""
      GOTO, nextOrbit
   ENDIF

; initialize PR variables/arrays and read 2A25 fields
   SAMPLE_RANGE=0
   START_SAMPLE=0
   num_range = NUM_RANGE_2A25
   dbz_2a25=FLTARR(sample_range>1,1,num_range)
   rain_2a25 = FLTARR(sample_range>1,1,num_range)
   surfRain_2a25=FLTARR(sample_range>1,RAYSPERSCAN)
   geolocation=FLTARR(2,RAYSPERSCAN,sample_range>1)
   rangeBinNums=INTARR(sample_range>1,RAYSPERSCAN,7)
   rainFlag=INTARR(sample_range>1,RAYSPERSCAN)
   rainType=INTARR(sample_range>1,RAYSPERSCAN)
   pia3=FLTARR(3,sample_range>1,RAYSPERSCAN)
   status = read_pr_2a25_fields( file_2a25, DBZ=dbz_2a25, RAIN=rain_2a25,   $
                                 TYPE=rainType, SURFACE_RAIN=surfRain_2a25, $
                                 GEOL=geolocation, RANGE_BIN=rangeBinNums,  $
                                 RN_FLAG=rainFlag, PIA=pia3 )
   IF ( status NE 0 ) THEN BEGIN
      PRINT, ""
      PRINT, "ERROR reading fields from ", file_2a25
      PRINT, "Skipping events for orbit = ", orbit
      skip_gr_events, lun0, nsites
      PRINT, ""
      GOTO, nextOrbit
   ENDIF

;*******************************************************************************
;*******************************************************************************
; NEED TO GET A 'COMMON' SET OF SCANS BETWEEN ALL PR PRODUCTS READ/USED?  THEY
; MAY NOT BE ABLE TO SHARE THE 2A25 GEOLOCATION, AS ASSUMED BY THIS ALGORITHM.
; Check for same number of PR footprints, for now.
;*******************************************************************************
;*******************************************************************************

; verify that we are looking at the same subset of scans (size-wise, anyway)
; between the 1c21 and 2a25 product
   IF N_ELEMENTS(landOceanFlag) NE N_ELEMENTS(rainFlag) THEN BEGIN
      PRINT, ""
      PRINT, "Mismatch between #scans in ", file_2a25, " and ", file_1c21
      PRINT, "Quitting processing."
      GOTO, bailOut
   ENDIF

; split GEOL data fields into prlats and prlons arrays
   prlons = FLTARR(RAYSPERSCAN,sample_range>1)
   prlats = FLTARR(RAYSPERSCAN,sample_range>1)
   prlons[*,*] = geolocation[1,*,*]
   prlats[*,*] = geolocation[0,*,*]

; NOTE THAT THE PIA AND GEOLOCATION ARRAYS ARE IN (RAY,SCAN) COORDINATES, WHILE
; OTHER ARRAYS ARE IN (SCAN,RAY) COORDINATE ORDER.  NEED TO ACCOUNT FOR THIS
; WHEN USING "pr_master_idx" ARRAY INDICES.

; extract the "final adjusted PIA estimate" subarray from the full 2A25 dataset
; and transpose to [scan,ray] order
pia = TRANSPOSE(REFORM( pia3[0,*,*] ))

; Extract the 2-D range bin number of the bright band level from the 3-D array
;   and initialize a matching bright band height array
   BB_Bins = rangeBinNums[*,*,3]
   BB_hgt = FLOAT(BB_Bins)
   BB_hgt[*,*] = BBHGT_UNDEFINED
   
; read 2A23 status fields
; The following test allows PR processing to proceed without the
; 2A-23 data file being available.

   havefile2a23 = 1
   IF ( origFile23Name EQ 'no_2A23_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "No 2A23 file, skipping 2A23 processing for orbit = ", orbit
      PRINT, ""
      havefile2A23 = 0
   ENDIF ELSE BEGIN
      status_2a23=INTARR(sample_range>1,RAYSPERSCAN)
      bbstatus=INTARR(sample_range>1,RAYSPERSCAN)
      status = read_pr_2a23_fields( file_2a23, STATUSFLAG=status_2a23, $
                                    BBstatus=bbstatus)
      IF ( status NE 0 ) THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_2a23
         PRINT, "Skipping 2A23 processing for orbit = ", orbit
         PRINT, ""
         havefile2a23 = 0
      ENDIF
     ; verify that we are looking at the same subset of scans (size-wise, anyway)
     ; between the 1c21 and 2a23 product
      IF N_ELEMENTS(landOceanFlag) NE N_ELEMENTS(status_2a23) THEN BEGIN
         PRINT, ""
         PRINT, "Mismatch between #scans in ", file_2a23, " and ", file_1c21
         PRINT, "Skipping 2A23 processing for orbit = ", orbit
         PRINT, ""
         havefile2a23 = 0
      ENDIF
   ENDELSE

; read 2B31 rainrate field
; The following test allows PR processing to proceed without the
; 2B-31 data file being available.

   havefile2b31 = 1
   IF ( origFile31Name EQ 'no_2B31_file' ) THEN BEGIN
      PRINT, ""
      PRINT, "No 2B31 file, skipping 2B31 processing for orbit = ", orbit
      PRINT, ""
      havefile2b31 = 0
   ENDIF ELSE BEGIN
      surfRain_2b31=FLTARR(sample_range>1,RAYSPERSCAN)
      status = read_pr_2b31_fields( file_2b31, surfRain_2b31)
      IF ( status NE 0 ) THEN BEGIN
         PRINT, ""
         PRINT, "ERROR reading fields from ", file_2b31
         PRINT, "Skipping 2B31 processing for orbit = ", orbit
         PRINT, ""
         havefile2b31 = 0
      ENDIF
     ; verify that we are looking at the same subset of scans (size-wise, anyway)
     ; between the 1c21 and 2b31 product
      IF N_ELEMENTS(landOceanFlag) NE N_ELEMENTS(surfRain_2b31) THEN BEGIN
         PRINT, ""
         PRINT, "Mismatch between #scans in ", file_2b31, " and ", file_1c21
         PRINT, "Skipping 2B31 processing for orbit = ", orbit
         PRINT, ""
         havefile2b31 = 0
      ENDIF
   ENDELSE

   lastsite = ""
FOR igv=0,nsites-1  DO BEGIN
  ;  - grab each overpassed site's information from the string array
   dataGV = dataGVarr[igv]

  ; parse dataGV into its component fields: event_num, orbit number, siteID,
  ; overpass datetime, time in ticks, site lat, site lon, site elev,
  ; 1CUF file unique pathname
   parsed=STRSPLIT( dataGV, '|', count=nGVfields, /extract )
   CASE nGVfields OF
     9 : BEGIN   ; legacy control file format
           event_num = LONG( parsed[0] )
           orbit = parsed[1]
           siteID = parsed[2]    ; GPMGV siteID
           pr_dtime = parsed[3]
           pr_dtime_ticks = parsed[4]
           siteLat = FLOAT( parsed[5] )
           siteLon = FLOAT( parsed[6] )
           siteElev = FLOAT( parsed[7] )
           origUFName = parsed[8]  ; filename as listed in/on the database/disk
         END
     6 : BEGIN   ; streamlined control file format, already have orbit #
           siteID = parsed[0]    ; GPMGV siteID
           pr_dtime = parsed[1]
           pr_dtime_ticks = ticks_from_datetime( pr_dtime )
           IF STRING(pr_dtime_ticks) EQ "Bad Datetime" THEN BEGIN
              print, ""
              print, "Bad overpass datetime field in control file:"
              print, dataGV
              print, "Skipping site event." & print, ""
              GOTO, nextGVfile
           END
           siteLat = FLOAT( parsed[2] )
           siteLon = FLOAT( parsed[3] )
           siteElev = FLOAT( parsed[4] )
           origUFName = parsed[5]  ; filename as listed in/on the database/disk
         END
     ELSE : BEGIN
           print, ""
           print, "Incorrect number of GR-type fields in control file:"
           print, dataGV
           print, "Skipping site event." & print, ""
           GOTO, nextGVfile
         END
   ENDCASE

  ; assume that if siteElev value is 4.0 or more, its units are m - km needed
   IF (siteElev GE 4.0) THEN siteElev=siteElev/1000.
  ; don't allow below-sea-level siteElev to be below -400 m (-0.4 km) (Dead Sea)
   IF (siteElev LT -0.4) THEN siteElev=( (siteElev/1000.) > (-0.4) )

  ; adding the well-known (or local) path to get the fully-qualified file name:
   file_1CUF = in_base_dir + "/" + origUFName
   base_1CUF = file_basename(file_1CUF)
   IF ( base_1CUF eq 'no_1CUF_file' ) THEN BEGIN
      PRINT, "No 1CUF file for orbit = ", orbit, ", site = ", $
              siteID, ", skipping."
      GOTO, nextGVfile
   ENDIF
   IF ( siteID EQ lastsite ) THEN BEGIN
      PRINT, "Multiple 1CUF files for orbit = ", orbit, ", site = ", $
              siteID, ", skipping."
      lastsite = siteID
      GOTO, nextGVfile
   ENDIF
   lastsite = siteID

; store the file basename in the string array to be passed to gen_geo_match_netcdf()
   infileNameArr[4] = base_1CUF

   PRINT, ""
   PRINT, STRING(igv+1, FORMAT='(I0)'), ": ", pr_dtime, "  ", $
          siteID, siteLat, siteLon
;   PRINT, igv+1, ": ", file_1CUF

   PRINT, '--------------------------------------------------------------------'
   PRINT, ""

  ; initialize a gv-centered map projection for the ll<->xy transformations:
   sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=siteLat, $
                         center_longitude=siteLon )
  ; PR-site latitude and longitude differences for coarse filter
   max_deg_lat = rough_threshold / 111.1
   max_deg_lon = rough_threshold / (cos(!DTOR*siteLat) * 111.1 )

  ; copy/unzip/open the UF file and read the entire volume scan into an
  ;   RSL_in_IDL radar structure, and then close UF file and delete copy:

   status=get_rsl_radar(file_1CUF, radar)
   IF ( status NE 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error reading radar structure from file ", file_1CUF
      PRINT, ""
      GOTO, nextGVfile
   ENDIF

  ; set up the structure holding the UF IDs for the fields we find in this file
  ; - the default values in this structure must be coordinated with those
  ;   defined in gen_geo_match_netcdf.pro
   ufstruct={ CZ_ID:    'Unspecified', $
              ZDR_ID  : 'Unspecified', $
              KDP_ID  : 'Unspecified', $
              RHOHV_ID: 'Unspecified', $
              RR_ID:    'Unspecified', $
              HID_ID:   'Unspecified', $
              D0_ID:    'Unspecified', $
              NW_ID:    'Unspecified' }

  ; need to define this parameter whether or not KD or DR volumes are present
   DR_KD_MISSING = (radar_dp_parameters()).DR_KD_MISSING

  ; find the volume with the correct reflectivity field for the GV site/source,
  ;   and the ID of the field itself
   gv_z_field = ''
   z_vol_num = get_site_specific_z_volume( siteID, radar, gv_z_field )
   IF ( z_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "Error finding Z volume in radar structure from file: ", file_1CUF
      PRINT, ""
      GOTO, nextGVfile
   ENDIF ELSE ufstruct.CZ_ID = gv_z_field

  ; find the volume with the Zdr field for the GV site/source
   gv_zdr_field = ''
   zdr_field2get = 'DR'
   zdr_vol_num = get_site_specific_z_volume( siteID, radar, gv_zdr_field, $
                                            UF_FIELD=zdr_field2get )
   IF ( zdr_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'DR' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_zdr = 0
   ENDIF ELSE BEGIN
      have_gv_zdr = 1
      ufstruct.ZDR_ID = 'DR'
;      DR_KD_MISSING = (radar_dp_parameters()).DR_KD_MISSING
   ENDELSE

  ; find the volume with the Kdp field for the GV site/source
   gv_kdp_field = ''
   kdp_field2get = 'KD'
   kdp_vol_num = get_site_specific_z_volume( siteID, radar, gv_kdp_field, $
                                            UF_FIELD=kdp_field2get )
   IF ( kdp_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'KD' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_kdp = 0
   ENDIF ELSE BEGIN
      have_gv_kdp = 1
      ufstruct.KDP_ID = 'KD'
;      DR_KD_MISSING = (radar_dp_parameters()).DR_KD_MISSING
   ENDELSE

  ; find the volume with the RHOhv field for the GV site/source
   gv_rhohv_field = ''
   rhohv_field2get = 'RH'
   rhohv_vol_num = get_site_specific_z_volume( siteID, radar, gv_rhohv_field, $
                                            UF_FIELD=rhohv_field2get )
   IF ( rhohv_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'RH' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_rhohv = 0
   ENDIF ELSE BEGIN
      have_gv_rhohv = 1
      ufstruct.RHOHV_ID = 'RH'
   ENDELSE

  ; find the volume with the rainrate field for the GV site/source
   gv_rr_field = ''
   rr_field2get = 'RR'
   rr_vol_num = get_site_specific_z_volume( siteID, radar, gv_rr_field, $
                                            UF_FIELD=rr_field2get )
   IF ( rr_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'RR' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_rr = 0
   ENDIF ELSE BEGIN
      have_gv_rr = 1
      ufstruct.RR_ID = 'RR'
   ENDELSE

  ; find the volume with the HID field for the GV site/source
   gv_hid_field = ''
   hid_field2get = 'FH'
   hid_vol_num = get_site_specific_z_volume( siteID, radar, gv_hid_field, $
                                             UF_FIELD=hid_field2get )
   IF ( hid_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'FH' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_hid = 0
   ENDIF ELSE BEGIN
      have_gv_hid = 1
      ufstruct.HID_ID = 'FH'
     ; need #categories for netcdf dimensioning of tocdf_gv_dp_hid
      HID_structs = radar_dp_parameters()
      n_hid_cats = HID_structs.n_hid_cats
   ENDELSE

  ; find the volume with the D0 field for the GV site/source
   gv_dzero_field = ''
   dzero_field2get = 'D0'
   dzero_vol_num = get_site_specific_z_volume( siteID, radar, gv_dzero_field, $
                                               UF_FIELD=dzero_field2get )
   IF ( dzero_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'D0' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_dzero = 0
   ENDIF ELSE BEGIN
      have_gv_dzero = 1
      ufstruct.D0_ID = 'D0'
   ENDELSE

  ; find the volume with the Nw field for the GV site/source
   gv_nw_field = ''
   nw_field2get = 'NW'
   nw_vol_num = get_site_specific_z_volume( siteID, radar, gv_nw_field, $
                                            UF_FIELD=nw_field2get )
   IF ( nw_vol_num LT 0 )  THEN BEGIN
      PRINT, ""
      PRINT, "No 'NW' volume in radar structure from file: ", file_1CUF
      PRINT, ""
      have_gv_nw = 0
   ENDIF ELSE BEGIN
      have_gv_nw = 1
      ufstruct.NW_ID = 'NW'
   ENDELSE

  ; get the number of elevation sweeps in the vol, and the array of elev angles
   num_elevations = get_sweep_elevs( z_vol_num, radar, elev_angle )
  ; make a copy of the array of elevations, from which we eliminate any
  ;   duplicate tilt angles for subsequent data processing/output
;   idx_uniq_elevs = UNIQ(elev_angle)
   uniq_elev_angle = elev_angle
   idx_uniq_elevs = UNIQ_SWEEPS(elev_angle, uniq_elev_angle)

   tocdf_elev_angle = elev_angle[idx_uniq_elevs]
   num_elevations_out = N_ELEMENTS(tocdf_elev_angle)
   IF num_elevations NE num_elevations_out THEN BEGIN
      print, ""
      print, "Duplicate sweep elevations ignored!"
      print, "Original sweep elevations:"
      print, elev_angle
      print, "Unique sweep elevations to be processed/output"
      print, tocdf_elev_angle
   ENDIF

  ; precompute cos(elev) for later repeated use
   cos_elev_angle = COS( tocdf_elev_angle * !DTOR )

  ; Get the times of the first ray in each sweep -- text_sweep_times will be
  ;   formatted as YYYY-MM-DD hh:mm:ss, e.g., '2008-07-09 00:10:56'
   num_times = get_sweep_times( z_vol_num, radar, dtimestruc )
   text_sweep_times = dtimestruc.textdtime  ; STRING array, human-readable
   ticks_sweep_times = dtimestruc.ticks     ; DOUBLE array, time in unix ticks
   IF num_elevations NE num_elevations_out THEN BEGIN
      ticks_sweep_times = ticks_sweep_times[idx_uniq_elevs]
      text_sweep_times =  text_sweep_times[idx_uniq_elevs]
   ENDIF

  ; Determine an upper limit to how many PR footprints fall inside the analysis
  ;   area, so that we can hold x, y, and various z values for each element to
  ;   analyze.  We gave the PR a 4km resolution in the 'include' file
  ;   pr_params.inc, and use this nominal resolution to figure out how many
  ;   of these are required to cover the in-range area.

   grid_area_km = rough_threshold * rough_threshold  ; could use area of circle
   max_pr_fp = grid_area_km / NOM_PR_RES_KM

  ; Create temp array of PR (ray, scan) 1-D index locators for in-range points.
  ;   Use flag values of -1 for 'bogus' PR points (out-of-range PR footprints
  ;   just adjacent to the first/last in-range point of the scan), or -2 for
  ;   off-PR-scan-edge but still-in-range points.  These bogus points will then
  ;   totally enclose the set of in-range, in-scan points and allow gridding of
  ;   the in-range dataset to a regular grid using a nearest-neighbor analysis,
  ;   assuring that the bounds of the in-range data are preserved (this gridding
  ;   in not needed or done within the current analysis).
   pr_master_idx = LONARR(max_pr_fp)
   pr_master_idx[*] = -99L

  ; Create temp array used to flag whether there are ANY above-threshold PR bins
  ; in the ray.  If none, we'll skip the time-consuming GV LUT computations.
   pr_echoes = BYTARR(max_pr_fp)
   pr_echoes[*] = 0B             ; initialize to zero (skip the PR ray)

  ; Create temp arrays to hold lat/lon of all PR footprints to be analyzed,
  ;   including those extrapolated to mark the edge of the scan
   pr_lon_sfc = FLTARR(max_pr_fp)
   pr_lat_sfc = pr_lon_sfc

  ; create temp subarrays with additional dimension num_elevations_out to hold
  ;   parallax-adjusted PR point X,Y and lon/lat coordinates, and PR corner X,Ys
   pr_x_center = FLTARR(max_pr_fp, num_elevations_out)
   pr_y_center = pr_x_center
   pr_x_corners = FLTARR(4, max_pr_fp, num_elevations_out)
   pr_y_corners = pr_x_corners
  ; holds lon/lat array returned by MAP_PROJ_INVERSE()
   pr_lon_lat = DBLARR(2, max_pr_fp, num_elevations_out)

  ; restrict max range at each elevation to where beam center is 19.5 km or less
   max_ranges = FLTARR( num_elevations_out )
   FOR i = 0, num_elevations_out - 1 DO BEGIN
      rsl_get_slantr_and_h, range_threshold_km, tocdf_elev_angle[i], $
                            slant_range, max_ht_at_range
      IF ( max_ht_at_range LT 19.5 ) THEN BEGIN
         max_ranges[i] = range_threshold_km
      ENDIF ELSE BEGIN
         max_ranges[i] = get_range_km_at_beam_hgt_km(tocdf_elev_angle[i], 19.5)
      ENDELSE
   ENDFOR

  ; ======================================================================================================

  ; GEO-Preprocess the PR data, extracting rays that intersect this radar volume
  ; within the specified range threshold, and computing footprint x,y corner
  ; coordinates and adjusted center lat/lon at each of the intersection sweep
  ; intersection heights, taking into account the parallax of the PR rays.
  ; (Optionally) surround the PR footprints within the range threshold with a border
  ; of "bogus" tagged PR points to facilitate any future gridding of the data.
  ; Algorithm assumes that PR footprints are contiguous, non-overlapping,
  ; and quasi-rectangular in their native ray,scan coordinates, and that the PR
  ; middle ray of the scan is nadir-pointing (zero roll/pitch of satellite).

  ; First, find scans with any point within range of the radar volume, roughly
   start_scan = 0 & end_scan = 0 & nscans2do = 0
   start_found = 0
   FOR scan_num = 0,SAMPLE_RANGE-1  DO BEGIN
      found_one = 0
      FOR ray_num = 0,RAYSPERSCAN-1  DO BEGIN
         ; Compute distance between GV radar and PR sample lats/lons using
         ;   crude, fast algorithm
         IF ( ABS(prlons[ray_num,scan_num]-siteLon) LT max_deg_lon ) AND $
            ( ABS(prlats[ray_num,scan_num]-siteLat) LT max_deg_lat ) THEN BEGIN
            found_one = 1
            IF (start_found EQ 0) THEN BEGIN
               start_found = 1
               start_scan = scan_num
            ENDIF
            end_scan = scan_num        ; tag as last scan within range
            nscans2do = nscans2do + 1
            BREAK                      ; skip the rest of the rays for this scan
         ENDIF
      ENDFOR
      IF ( start_found EQ 1 AND found_one EQ 0 ) THEN BREAK   ; no more in range
   ENDFOR

   IF ( nscans2do EQ 0 ) THEN GOTO, nextGVfile

;-------------------------------------------------------------------------------
  ; Populate arrays holding 'exact' PR at-surface X and Y and range values for
  ; the in-range subset of scans.  THESE ARE NOT WRITTEN TO NETCDF FILE - YET.
   XY_km = map_proj_forward( prlons[*,start_scan:end_scan], $
                             prlats[*,start_scan:end_scan], $
                             map_structure=smap ) / 1000.
   pr_x0 = XY_km[0,*]
   pr_y0 = XY_km[1,*]
   pr_x0 = REFORM( pr_x0, RAYSPERSCAN, nscans2do, /OVERWRITE )
   pr_y0 = REFORM( pr_y0, RAYSPERSCAN, nscans2do, /OVERWRITE )
   precise_range = SQRT( pr_x0^2 + pr_y0^2 )
 
   numPRrays = 0      ; number of in-range, scan-edge, and range-adjacent points
   numPRinrange = 0   ; number of in-range-only points found
  ; Variables used to find 'farthest from nadir' in-range PR footprint:
   maxrayidx = 0
   minrayidx = RAYSPERSCAN-1

;-------------------------------------------------------------------------------
  ; Identify actual PR points within range of the radar, actual PR points just
  ; off the edge of the range cutoff, and extrapolated PR points along the edge
  ; of the scans but within range of the radar.  Tag each point as to these 3
  ; types, and compute parallax-corrected x,y and lat/lon coordinates for these
  ; points at PR ray's intersection of each sweep elevation.  Compute PR
  ; footprint corner x,y's for the first type of points (actual PR points
  ; within the cutoff range).

  ; flag for adding 'bogus' point if in-range at edge of scan PR (2), or just
  ;   beyond max_ranges[elev] (-1), or just a regular, in-range point (1):
   action2do = 0  ; default -- do nothing

   FOR scan_num = start_scan,end_scan  DO BEGIN
      subset_scan_num = scan_num - start_scan
     ; prep variables for parallax computations
      m = 0.0        ; SLOPE AS DX/DY
      dy_sign = 0.0  ; SENSE IN WHICH Y CHANGES WITH INCR. SCAN ANGLE, = -1 OR +1
      get_scan_slope_and_sense, smap, prlats, prlons, scan_num, RAYSPERSCAN, $
                                m, dy_sign

      FOR ray_num = 0,RAYSPERSCAN-1  DO BEGIN
        ; Set flag value according to where the PR footprint lies w.r.t. the GV radar.
         action2do = 0  ; default -- do nothing

        ; is to-sfc projection of any point along PR ray is within range of GV volume?
         IF ( precise_range[ray_num,subset_scan_num] LE max_ranges[0] ) THEN BEGIN
           ; add point to subarrays for PR 2D index and for footprint lat/lon
           ; - MAKE THE INDEX IN TERMS OF THE (SCAN,RAY) COORDINATE ARRAYS
            pr_master_idx[numPRrays] = LONG(ray_num) * LONG(SAMPLE_RANGE) + LONG(scan_num)
            pr_lat_sfc[numPRrays] = prlats[ray_num,scan_num]
            pr_lon_sfc[numPRrays] = prlons[ray_num,scan_num]

            action2do = 1                      ; set up to process this in-range point
            maxrayidx = ray_num > maxrayidx    ; track highest ray num occurring in GV area
            minrayidx = ray_num < minrayidx    ; track lowest ray num in GV area
            numPRinrange = numPRinrange + 1    ; increment # of actual in-range footprints

	   ; determine whether the PR ray has any bins above the dBZ threshold
	   ; - look at 2A-25 corrected Z between 0.75 and 19.25 km
	    top1C21gate = 0 & botm1C21gate = 0
            top2A25gate = 0 & botm2A25gate = 0
            gate_num_for_height, 19.25, GATE_SPACE, cos_inc_angle,  $
                      ray_num, scan_num, binS, rayStart,            $
                      GATE1C21=top1C21gate, GATE2A25=top2A25gate
            gate_num_for_height, 0.75, GATE_SPACE, cos_inc_angle,   $
                      ray_num, scan_num, binS, rayStart,            $
                      GATE1C21=botm1C21gate, GATE2A25=botm2A25gate
           ; use the above-threshold bin counting in get_pr_layer_average()
            dbz_ray_avg = get_pr_layer_average(top2A25gate, botm2A25gate,   $
                                 scan_num, ray_num, dbz_2a25, DBZSCALE2A25, $
                                 PR_DBZ_MIN, numPRgates )
            IF ( numPRgates GT 0 ) THEN pr_echoes[numPRrays] = 1B

	   ; while we are here, compute bright band height for the ray
            IF ( BB_Bins[scan_num,ray_num] LE 79 ) THEN BEGIN
               BB_hgt[scan_num,ray_num] = $
                (79-BB_Bins[scan_num,ray_num]) * GATE_SPACE * cos_inc_angle[ray_num]
            ENDIF ELSE BEGIN
               BB_hgt[scan_num,ray_num] = BB_MISSING
            ENDELSE

           ; If PR scan edge point, then set flag to add bogus PR data point to
           ;   subarrays for each PR spatial field, with PR index flagged as
           ;   "off-scan-edge", and compute the extrapolated location parameters
            IF ( (ray_num EQ 0 OR ray_num EQ RAYSPERSCAN-1) AND mark_edges EQ 1 ) THEN BEGIN
              ; set flag and find the x,y offsets to extrapolated off-edge point
               action2do = 2                   ; set up to also process bogus off-edge point
              ; extrapolate X and Y to the bogus, off-scan-edge point
               if ( ray_num LT RAYSPERSCAN/2 ) then begin 
                  ; offsets extrapolate X and Y to where (angle = angle-1) would be
                  ; Get offsets using the next footprint's X and Y
                  Xoff = pr_x0[ray_num, subset_scan_num] - pr_x0[ray_num+1, subset_scan_num]
                  Yoff = pr_y0[ray_num, subset_scan_num] - pr_y0[ray_num+1, subset_scan_num]
               endif else begin
                  ; extrapolate X and Y to where (angle = angle+1) would be
                  ; Get offsets using the preceding footprint's X and Y
                  Xoff = pr_x0[ray_num, subset_scan_num] - pr_x0[ray_num-1, subset_scan_num]
                  Yoff = pr_y0[ray_num, subset_scan_num] - pr_y0[ray_num-1, subset_scan_num]
               endelse
              ; compute the resulting lon/lat value of the extrapolated footprint
              ;  - we will add to temp lat/lon arrays in action sections, below
               XX = pr_x0[ray_num, subset_scan_num] + Xoff
               YY = pr_y0[ray_num, subset_scan_num] + Yoff
              ; need x and y in meters for MAP_PROJ_INVERSE:
               extrap_lon_lat = MAP_PROJ_INVERSE (XX*1000., YY*1000., MAP_STRUCTURE=smap)
            ENDIF

         ENDIF ELSE BEGIN
            IF mark_edges EQ 1 THEN BEGIN
              ; Is footprint immediately adjacent to the in-range area?  If so, then
              ;   'ring' the in-range points with a border of PR bogosity, even for
              ;   scans with no rays in-range. (Is like adding a range ring at the
              ;   outer edge of the in-range area)
               IF ( precise_range[ray_num,subset_scan_num] LE $
                    (max_ranges[0] + NOM_PR_RES_KM*1.5) ) THEN BEGIN
                   pr_master_idx[numPRrays] = -1L  ; store beyond-range indicator as PR index
                   pr_lat_sfc[numPRrays] = prlats[ray_num,scan_num]
                   pr_lon_sfc[numPRrays] = prlons[ray_num,scan_num]
                   action2do = -1  ; set up to process bogus beyond-range point
               ENDIF
            ENDIF
         ENDELSE          ; ELSE for precise range[] LE max_ranges[0]

        ; If/As flag directs, add PR point(s) to the subarrays for each elevation
         IF ( action2do NE 0 ) THEN BEGIN
           ; compute the at-surface x,y values for the 4 corners of the current PR footprint
            xy = footprint_corner_x_and_y( subset_scan_num, ray_num, pr_x0, pr_y0, $
                                           nscans2do, RAYSPERSCAN )
           ; compute parallax-corrected x-y values for each sweep height
            FOR i = 0, num_elevations_out - 1 DO BEGIN
              ; NEXT 4+ COMMANDS COULD BE ITERATIVE, TO CONVERGE TO A dR THRESHOLD (function?)
              ; compute GV beam height for elevation angle at precise_range
               rsl_get_slantr_and_h, precise_range[ray_num,subset_scan_num], $
                                     tocdf_elev_angle[i], slant_range, hgt_at_range

              ; compute PR parallax corrections dX and dY at this height (adjusted to MSL),
              ;   and apply to footprint center X and Y to get XX and YY
               get_parallax_dx_dy, hgt_at_range + siteElev, ray_num, RAYSPERSCAN, $
                                   m, dy_sign, tan_inc_angle, dx, dy
               XX = pr_x0[ray_num, subset_scan_num] + dx
               YY = pr_y0[ray_num, subset_scan_num] + dy

              ; recompute precise_range of parallax-corrected PR footprint from radar (if converging)

              ; compute lat,lon of parallax-corrected PR footprint center:
               lon_lat = MAP_PROJ_INVERSE( XX*1000., YY*1000., MAP_STRUCTURE=smap )  ; x and y in meters

              ; compute parallax-corrected X and Y coordinate values for the PR
              ;   footprint corners; hold in temp arrays xcornerspc and ycornerspc
               xcornerspc = xy[0,*] + dx
               ycornerspc = xy[1,*] + dy

              ; store PR-GV sweep intersection (XX,YY), offset lat and lon, and
              ;  (if non-bogus) corner (x,y)s in elevation-specific slots
               pr_x_center[numPRrays,i] = XX
               pr_y_center[numPRrays,i] = YY
               pr_x_corners[*,numPRrays,i] = xcornerspc
               pr_y_corners[*,numPRrays,i] = ycornerspc
               pr_lon_lat[*,numPRrays,i] = lon_lat
            ENDFOR
            numPRrays = numPRrays + 1   ; increment counter for # PR rays stored in arrays
         ENDIF

         IF ( action2do EQ 2 ) THEN BEGIN
           ; add another PR footprint to the analyzed set, to delimit the PR scan edge
            pr_master_idx[numPRrays] = -2L    ; store off-scan-edge indicator as PR index
            pr_lat_sfc[numPRrays] = extrap_lon_lat[1]  ; store extrapolated lat/lon
            pr_lon_sfc[numPRrays] = extrap_lon_lat[0]

            FOR i = 0, num_elevations_out - 1 DO BEGIN
              ; - grab the parallax-corrected footprint center and corner x,y's just
              ;     stored for the in-range PR edge point, and apply Xoff and Yoff offsets
               XX = pr_x_center[numPRrays-1,i] + Xoff
               YY = pr_y_center[numPRrays-1,i] + Yoff
               xcornerspc = pr_x_corners[*,numPRrays-1,i] + Xoff
               ycornerspc = pr_y_corners[*,numPRrays-1,i] + Yoff
              ; - compute lat,lon of parallax-corrected PR footprint center:
               lon_lat = MAP_PROJ_INVERSE(XX*1000., YY*1000., MAP_STRUCTURE=smap)  ; x,y to m
              ; store in elevation-specific slots
               pr_x_center[numPRrays,i] = XX
               pr_y_center[numPRrays,i] = YY
               pr_x_corners[*,numPRrays,i] = xcornerspc
               pr_y_corners[*,numPRrays,i] = ycornerspc
               pr_lon_lat[*,numPRrays,i] = lon_lat
            ENDFOR
            numPRrays = numPRrays + 1
         ENDIF

      ENDFOR              ; ray_num
   ENDFOR                 ; scan_num = start_scan,end_scan 

  ; ONE TIME ONLY: compute max diagonal size of a PR footprint, halve it,
  ;   and assign to max_PR_footprint_diag_halfwidth.  Ignore the variability
  ;   with height.  Take middle scan of PR/GR overlap within subset arrays:
   subset_scan_4size = FIX( (end_scan-start_scan)/2 )
  ; find which ray used was farthest from nadir ray at RAYSPERSCAN/2
   nadir_off_low = ABS(minrayidx - RAYSPERSCAN/2)
   nadir_off_hi = ABS(maxrayidx - RAYSPERSCAN/2)
   ray4size = (nadir_off_hi GT nadir_off_low) ? maxrayidx : minrayidx
  ; get PR footprint max diag extent at [ray4size, scan4size], and halve it
  ; Is it guaranteed that [subset_scan4size,ray4size] is one of our in-range
  ;   points?  Don't know, so get the corner x,y's for this point
   xy = footprint_corner_x_and_y( subset_scan_4size, ray4size, pr_x0, pr_y0, $
                                  nscans2do, RAYSPERSCAN )
   diag1 = SQRT((xy[0,0]-xy[0,2])^2+(xy[1,0]-xy[1,2])^2)
   diag2 = SQRT((xy[0,1]-xy[0,3])^2+(xy[1,1]-xy[1,3])^2)
   max_PR_footprint_diag_halfwidth = (diag1 > diag2) / 2.0

  ; end of PR GEO-preprocessing

  ; ======================================================================================================

  ; Initialize and/or populate data fields to be written to the netCDF file.
  ; NOTE WE DON'T SAVE THE SURFACE X,Y FOOTPRINT CENTERS AND CORNERS TO NETCDF

   IF ( numPRinrange GT 0 ) THEN BEGIN
     ; Trim the pr_master_idx, lat/lon temp arrays and x,y corner arrays down
     ;   to numPRrays elements in that dimension, in prep. for writing to netCDF
     ;    -- these elements are complete, data-wise
      tocdf_pr_idx = pr_master_idx[0:numPRrays-1]
      tocdf_x_poly = pr_x_corners[*,0:numPRrays-1,*]
      tocdf_y_poly = pr_y_corners[*,0:numPRrays-1,*]
      tocdf_lat = REFORM(pr_lon_lat[1,0:numPRrays-1,*])   ; 3D to 2D
      tocdf_lon = REFORM(pr_lon_lat[0,0:numPRrays-1,*])
      tocdf_lat_sfc = pr_lat_sfc[0:numPRrays-1]
      tocdf_lon_sfc = pr_lon_sfc[0:numPRrays-1]

     ; Create new subarrays of dimension equal to the numPRrays for each 2-D
     ;   PR science variable: landOceanFlag, nearSurfRain, nearSurfRain_2b31,
     ;   BBheight, rainFlag, rainType, BBstatus, status, PIA
      tocdf_2a25_srain = MAKE_ARRAY(numPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_2b31_srain = MAKE_ARRAY(numPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_BB_Hgt = MAKE_ARRAY(numPRrays, /float, VALUE=FLOAT_RANGE_EDGE)
      tocdf_rainflag = MAKE_ARRAY(numPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_raintype = MAKE_ARRAY(numPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_landocean = MAKE_ARRAY(numPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_status_2a23 = MAKE_ARRAY(numPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_BBstatus = MAKE_ARRAY(numPRrays, /int, VALUE=INT_RANGE_EDGE)
      tocdf_PIA = MAKE_ARRAY(numPRrays, /float, VALUE=FLOAT_RANGE_EDGE)

     ; Create new subarrays of dimensions (numPRrays, num_elevations_out) for each
     ;   3-D science and status variable: 
      tocdf_gv_dbz = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_stddev = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_max = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_zdr = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_zdr_stddev = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_zdr_max = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_kdp = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_kdp_stddev = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_kdp_max = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_rhohv = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_rhohv_stddev = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_rhohv_max = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_rr = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_rr_stddev = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_rr_max = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      IF ( have_gv_hid ) THEN $  ; don't have n_hid_cats unless have_gv_hid set
         tocdf_gv_HID = MAKE_ARRAY(n_hid_cats, numPRrays, num_elevations_out, $
                                /int, VALUE=INT_RANGE_EDGE)
      tocdf_gv_Dzero = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_Dzero_stddev = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                        VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_Dzero_max = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_Nw = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                               VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_Nw_stddev = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                      VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_Nw_max = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_1c21_dbz = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_2a25_dbz = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_2a25_rain = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                   VALUE=FLOAT_RANGE_EDGE)
      tocdf_top_hgt = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                 VALUE=FLOAT_RANGE_EDGE)
      tocdf_botm_hgt = MAKE_ARRAY(numPRrays, num_elevations_out, /float, $
                                  VALUE=FLOAT_RANGE_EDGE)
      tocdf_gv_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_gv_zdr_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_gv_kdp_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_gv_rhohv_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_gv_rr_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_gv_hid_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_gv_dzero_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_gv_nw_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_gv_expected = UINTARR(numPRrays, num_elevations_out)
      tocdf_1c21_z_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_2a25_z_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_2a25_r_rejected = UINTARR(numPRrays, num_elevations_out)
      tocdf_pr_expected = UINTARR(numPRrays, num_elevations_out)

     ; get the indices of actual PR footprints and load the 2D element subarrays
     ;   (no more averaging/processing needed) with data from the product arrays

      prgoodidx = WHERE( tocdf_pr_idx GE 0L, countprgood )
      IF ( countprgood GT 0 ) THEN BEGIN
         pr_idx_2get = tocdf_pr_idx[prgoodidx]
         tocdf_2a25_srain[prgoodidx] = surfRain_2a25[pr_idx_2get]
         IF ( havefile2b31 EQ 1 ) THEN BEGIN
            tocdf_2b31_srain[prgoodidx] = surfRain_2b31[pr_idx_2get]
         ENDIF
         tocdf_BB_Hgt[prgoodidx] = BB_Hgt[pr_idx_2get]
         tocdf_rainflag[prgoodidx] = rainFlag[pr_idx_2get]
         tocdf_raintype[prgoodidx] = rainType[pr_idx_2get]
         tocdf_landocean[prgoodidx] = landOceanFlag[pr_idx_2get]
         tocdf_PIA[prgoodidx] = pia[pr_idx_2get]
         IF ( havefile2a23 EQ 1 ) THEN BEGIN
            tocdf_status_2a23[prgoodidx] = status_2a23[pr_idx_2get]
            tocdf_BBstatus[prgoodidx] = BBstatus[pr_idx_2get]
         ENDIF
     ENDIF

     ; get the indices of any bogus scan-edge PR footprints
      predgeidx = WHERE( tocdf_pr_idx EQ -2, countpredge )
      IF ( countpredge GT 0 ) THEN BEGIN
        ; set the single-level PR element subarrays with the special values for
        ;   the extrapolated points
         tocdf_2a25_srain[predgeidx] = FLOAT_OFF_EDGE
         tocdf_2b31_srain[predgeidx] = FLOAT_OFF_EDGE
         tocdf_BB_Hgt[predgeidx] = FLOAT_OFF_EDGE
         tocdf_rainflag[predgeidx] = INT_OFF_EDGE
         tocdf_raintype[predgeidx] = INT_OFF_EDGE
         tocdf_landocean[predgeidx] = INT_OFF_EDGE
         tocdf_PIA[predgeidx] = FLOAT_OFF_EDGE
      ENDIF

   ENDIF ELSE BEGIN
      PRINT, ""
      PRINT, "No in-range PR footprints found for ", siteID, ", skipping."
      PRINT, ""
      GOTO, nextGVfile
   ENDELSE

  ; ================================================================================================
  ; Map this GV radar's data to the these PR footprints, where PR rays
  ; intersect the elevation sweeps.  This part of the algorithm continues
  ; in code in a separate file, included below:

   @polar2pr_resampling.pro

  ; ================================================================================================

  ; generate the netcdf matchup file path/name
   IF N_ELEMENTS(ncnameadd) EQ 1 THEN BEGIN
      fname_netCDF = NC_OUTDIR+'/'+GEO_MATCH_PRE+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+prverstr+'.'+verstr+'.'+ncnameadd+NC_FILE_EXT
   ENDIF ELSE BEGIN
      fname_netCDF = NC_OUTDIR+'/'+GEO_MATCH_PRE+siteID+'.'+DATESTAMP+'.' $
                      +orbit+'.'+prverstr+'.'+verstr+NC_FILE_EXT
   ENDELSE

  ; Create a netCDF file with the proper 'numPRrays' and 'num_elevations_out'
  ; dimensions, passing the global attribute values along
   ncfile = gen_geo_match_netcdf( fname_netCDF, numPRrays, tocdf_elev_angle, $
                                  ufstruct, prverstr, siteID, infileNameArr )
   IF ( fname_netCDF EQ "NoGeoMatchFile" ) THEN $
      message, "Error in creating output netCDF file "+fname_netCDF

  ; Open the netCDF file and write the completed field values to it
   ncid = NCDF_OPEN( ncfile, /WRITE )

  ; Write the scalar values to the netCDF file

   NCDF_VARPUT, ncid, 'site_ID', siteID
   NCDF_VARPUT, ncid, 'site_lat', siteLat
   NCDF_VARPUT, ncid, 'site_lon', siteLon
   NCDF_VARPUT, ncid, 'site_elev', siteElev
   NCDF_VARPUT, ncid, 'timeNearestApproach', pr_dtime_ticks
   NCDF_VARPUT, ncid, 'atimeNearestApproach', pr_dtime
   NCDF_VARPUT, ncid, 'timeSweepStart', ticks_sweep_times
   NCDF_VARPUT, ncid, 'atimeSweepStart', text_sweep_times
   NCDF_VARPUT, ncid, 'rangeThreshold', range_threshold_km
   NCDF_VARPUT, ncid, 'PR_dBZ_min', PR_DBZ_MIN
   NCDF_VARPUT, ncid, 'GV_dBZ_min', dBZ_min
   NCDF_VARPUT, ncid, 'rain_min', PR_RAIN_MIN

;  Write single-level results/flags to netcdf file

   NCDF_VARPUT, ncid, 'PRlatitude', tocdf_lat_sfc
   NCDF_VARPUT, ncid, 'PRlongitude', tocdf_lon_sfc
   NCDF_VARPUT, ncid, 'landOceanFlag', tocdf_landocean     ; data
    NCDF_VARPUT, ncid, 'have_landOceanFlag', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'nearSurfRain', tocdf_2a25_srain     ; data
    NCDF_VARPUT, ncid, 'have_nearSurfRain', DATA_PRESENT   ; data presence flag
   IF ( havefile2b31 EQ 1 ) THEN BEGIN
      NCDF_VARPUT, ncid, 'nearSurfRain_2b31', tocdf_2b31_srain      ; data
       NCDF_VARPUT, ncid, 'have_nearSurfRain_2b31', DATA_PRESENT    ; dp flag
   ENDIF
   NCDF_VARPUT, ncid, 'BBheight', tocdf_BB_Hgt        ; data
    NCDF_VARPUT, ncid, 'have_BBheight', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'rainFlag', tocdf_rainflag      ; data
    NCDF_VARPUT, ncid, 'have_rainFlag', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'rainType', tocdf_raintype      ; data
    NCDF_VARPUT, ncid, 'have_rainType', DATA_PRESENT  ; data presence flag
   NCDF_VARPUT, ncid, 'PIA', tocdf_PIA                ; data
    NCDF_VARPUT, ncid, 'have_PIA', DATA_PRESENT       ; data presence flag
   NCDF_VARPUT, ncid, 'rayIndex', tocdf_pr_idx
   IF ( havefile2a23 EQ 1 ) THEN BEGIN
      NCDF_VARPUT, ncid, 'status', tocdf_status_2a23
       NCDF_VARPUT, ncid, 'have_status', DATA_PRESENT    ; dp flag
      NCDF_VARPUT, ncid, 'BBstatus', tocdf_BBstatus
       NCDF_VARPUT, ncid, 'have_BBstatus', DATA_PRESENT    ; dp flag
   ENDIF

;  Write sweep-level results/flags to netcdf file & close it up

   NCDF_VARPUT, ncid, 'latitude', tocdf_lat
   NCDF_VARPUT, ncid, 'longitude', tocdf_lon
   NCDF_VARPUT, ncid, 'xCorners', tocdf_x_poly
   NCDF_VARPUT, ncid, 'yCorners', tocdf_y_poly
   NCDF_VARPUT, ncid, 'threeDreflect', tocdf_gv_dbz            ; data
    NCDF_VARPUT, ncid, 'have_threeDreflect', DATA_PRESENT      ; data presence flag
   NCDF_VARPUT, ncid, 'threeDreflectStdDev', tocdf_gv_stddev     ; data
   NCDF_VARPUT, ncid, 'threeDreflectMax', tocdf_gv_max            ; data
   IF ( have_gv_zdr ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Zdr', tocdf_gv_zdr               ; data
       NCDF_VARPUT, ncid, 'have_GR_Zdr', DATA_PRESENT        ; data presence flag
      NCDF_VARPUT, ncid, 'GR_ZdrStdDev', tocdf_gv_zdr_stddev  ; data
      NCDF_VARPUT, ncid, 'GR_ZdrMax', tocdf_gv_zdr_max        ; data
   ENDIF
   IF ( have_gv_kdp ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Kdp', tocdf_gv_kdp               ; data
       NCDF_VARPUT, ncid, 'have_GR_Kdp', DATA_PRESENT        ; data presence flag
      NCDF_VARPUT, ncid, 'GR_KdpStdDev', tocdf_gv_kdp_stddev  ; data
      NCDF_VARPUT, ncid, 'GR_KdpMax', tocdf_gv_kdp_max        ; data
   ENDIF
   IF ( have_gv_rhohv ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_RHOhv', tocdf_gv_rhohv               ; data
       NCDF_VARPUT, ncid, 'have_GR_RHOhv', DATA_PRESENT        ; data presence flag
      NCDF_VARPUT, ncid, 'GR_RHOhvStdDev', tocdf_gv_rhohv_stddev  ; data
      NCDF_VARPUT, ncid, 'GR_RHOhvMax', tocdf_gv_rhohv_max        ; data
   ENDIF
   IF ( have_gv_rr ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_rainrate', tocdf_gv_rr               ; data
       NCDF_VARPUT, ncid, 'have_GR_rainrate', DATA_PRESENT        ; data presence flag
      NCDF_VARPUT, ncid, 'GR_rainrateStdDev', tocdf_gv_rr_stddev  ; data
      NCDF_VARPUT, ncid, 'GR_rainrateMax', tocdf_gv_rr_max        ; data
   ENDIF
   IF ( have_gv_hid ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_HID', tocdf_gv_HID             ; data
       NCDF_VARPUT, ncid, 'have_GR_HID', DATA_PRESENT       ; data presence flag
   ENDIF
   IF ( have_gv_dzero ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Dzero', tocdf_gv_dzero               ; data
       NCDF_VARPUT, ncid, 'have_GR_Dzero', DATA_PRESENT           ; data presence flag
      NCDF_VARPUT, ncid, 'GR_DzeroStdDev', tocdf_gv_dzero_stddev  ; data
      NCDF_VARPUT, ncid, 'GR_DzeroMax', tocdf_gv_dzero_max        ; data
   ENDIF
   IF ( have_gv_nw ) THEN BEGIN
      NCDF_VARPUT, ncid, 'GR_Nw', tocdf_gv_Nw               ; data
       NCDF_VARPUT, ncid, 'have_GR_Nw', DATA_PRESENT        ; data presence flag
      NCDF_VARPUT, ncid, 'GR_NwStdDev', tocdf_gv_Nw_stddev  ; data
      NCDF_VARPUT, ncid, 'GR_NwMax', tocdf_gv_Nw_max        ; data
   ENDIF
   NCDF_VARPUT, ncid, 'dBZnormalSample', tocdf_1c21_dbz        ; data
    NCDF_VARPUT, ncid, 'have_dBZnormalSample', DATA_PRESENT    ; data presence flag
   NCDF_VARPUT, ncid, 'correctZFactor', tocdf_2a25_dbz         ; data
    NCDF_VARPUT, ncid, 'have_correctZFactor', DATA_PRESENT     ; data presence flag
   NCDF_VARPUT, ncid, 'rain', tocdf_2a25_rain                  ; data
    NCDF_VARPUT, ncid, 'have_rain', DATA_PRESENT               ; data presence flag
   NCDF_VARPUT, ncid, 'topHeight', tocdf_top_hgt
   NCDF_VARPUT, ncid, 'bottomHeight', tocdf_botm_hgt
   NCDF_VARPUT, ncid, 'n_gv_rejected', tocdf_gv_rejected
   NCDF_VARPUT, ncid, 'n_gv_zdr_rejected', tocdf_gv_zdr_rejected
   NCDF_VARPUT, ncid, 'n_gv_kdp_rejected', tocdf_gv_kdp_rejected
   NCDF_VARPUT, ncid, 'n_gv_rhohv_rejected', tocdf_gv_rhohv_rejected
   NCDF_VARPUT, ncid, 'n_gv_rr_rejected', tocdf_gv_rr_rejected
   NCDF_VARPUT, ncid, 'n_gv_hid_rejected', tocdf_gv_hid_rejected
   NCDF_VARPUT, ncid, 'n_gv_dzero_rejected', tocdf_gv_dzero_rejected
   NCDF_VARPUT, ncid, 'n_gv_nw_rejected', tocdf_gv_nw_rejected
   NCDF_VARPUT, ncid, 'n_gv_expected', tocdf_gv_expected
   NCDF_VARPUT, ncid, 'n_1c21_z_rejected', tocdf_1c21_z_rejected
   NCDF_VARPUT, ncid, 'n_2a25_z_rejected', tocdf_2a25_z_rejected
   NCDF_VARPUT, ncid, 'n_2a25_r_rejected', tocdf_2a25_r_rejected
   NCDF_VARPUT, ncid, 'n_pr_expected', tocdf_pr_expected

   NCDF_CLOSE, ncid

  ; gzip the finished netCDF file
   PRINT
   PRINT, "Output netCDF file:"
   PRINT, ncfile
   PRINT, "is being compressed."
   PRINT
   command = "gzip -v " + ncfile
   spawn, command

   IF keyword_set(plot_ppis) THEN BEGIN
     ; delete the two PPI windows at the end
      wdelete, !d.window
      wdelete, !d.window
   ENDIF

   nextGVfile:

ENDFOR    ; each GV site for orbit

nextOrbit:

ENDWHILE  ; each orbit/PR file set to process in control file

print, ""
print, "Done!"

bailOut:
CLOSE, lun0

END
