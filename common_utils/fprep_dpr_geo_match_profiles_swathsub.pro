;===============================================================================
;+
; Copyright © 2013, United States Government as represented by the
; Administrator for The National Aeronautics and Space Administration.
; All Rights Reserved.
;
; fprep_dpr_geo_match_profiles.pro
; - Morris/SAIC/GPM_GV  July 2013
;
; DESCRIPTION
; -----------
; Reads DPR and GR reflectivity and spatial fields from a selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and an array of actual range. Single-
; level arrays (pr_index, rainType, etc.) are replicated to the same number of
; levels/dimensions as the sweep-level variables (DPR and GR reflectivity etc.).
; "Bogus" border points that enclose the actual match-up data at each level are
; removed so that only the profiles with actual data are returned to the caller.
; All original/replicated spatial data fields are restored to the form of 2-D
; arrays of dimensions (number of PR rays, number of sweeps) to facilitate
; analysis as vertical profiles.
;
; For the array of heights passed, or for a default set of heights, the
; routine will compute an array of the dimensions of the sweep-level data
; that assigns each sample point in the sweep-level data to a fixed-height
; level based on the vertical midpoint of the sample.  The assigned values
; are the array index value of the corresponding height in the default/passed
; array of heights.
;
; The mean height of the bright band, and the array index of the highest and
; lowest fixed-height level affected by the bright band will be computed, and
; if the BBPARMS keyword is set, these values will be returned in the 'bbparms'
; structure supplied as the formal parameter.  See the code for rules on how
; fixed-height layers affected by the bright band are determined.  It is
; up to the caller to properly create and initialize the bbparms structure to be
; passed as the BBPARMS keyword parameter, as in the following example:
;
; bbparms = {meanBB : -99.99, BB_HgtLo : -99, BB_HgtHi : -99}
;
; The ALT_BB_HGT keyword allows the caller to provide either a single numerical
; value specifying the mean bright band height to be used, or a file of
; precomputed freezing level heights to be searched to find the BB height for
; the current site and orbit, when the mean BB height cannot be determined
; using BB field values in the DPR data.  If the binary keyword FORCEBB is also
; set, then the BB value specified by ALT_BB_HGT will be used regardless of
; whether the mean BB height can be determined from the DPR data.
;
; If the pctAbvThresh parameter is specified, then the function will also
; compute 4 arrays holding the percentage of raw bins included in the volume
; average whose physical values were at/above the fixed thresholds for:
;
; 1) DPR reflectivity (18 dBZ, or as defined in the geo_match netcdf file)
; 2) GR reflectivity (15 dBZ, or as defined in the geo_match netcdf file)
; 3) DPR rainrate (0.01 mm/h, or as defined in the geo_match netcdf file).
; 4) GR rainrate (uses same threshold as PR rainrate).
;
; These 3 thresholds are available in the "mygeometa" variable, a structure
; of type "geo_match_meta" (see dpr_geo_match_nc_structs.inc), populated in
; the call to read_dpr_geo_match_netcdf(), in the structure variables
; DPR_dBZ_min, GR_dBZ_min, and rain_min, respectively.
;
; If s2ku binary parameter is set, then the Liao/Meneghini S-to-Ku band
; reflectivity adjustment will be made to the volume-matched ground radar
; reflectivity field, gvz.
;
; PARAMETERS
; ----------
; ncfilepr     - fully qualified path/name of the geo_match netCDF file to read
;
; heights      - array of fixed height levels used to compute the height
;                categories assigned to the 3-D data samples.  If none is
;                provided, a default set of 13 levels from 1.5-19.5 km is used
;
; pctAbvThresh - compute arrays of the percent of bins in the geometric-matching
;                volume that were above their respective Z thresholds, specified
;                at the time the geo-match dataset was created.  Essentially a
;                measure of "beam-filling goodness".  100 percent = only those
;                matchup points where all the PR and GV bins in the volume
;                averages were above threshold (complete volume filled with
;                above threshold bin values).  0 percent = all matchup points
;                available, with no regard for thresholds
;
; gvconvective - GV reflectivity threshold at/above which GV data are considered
;                to be of Convective Rain Type.  Default = 35.0 if not specified.
;                If set to <= 0, then GV reflectivity is ignored in evaluating
;                whether PR-indicated Stratiform Rain Type matches GV type.
;
; gvstratiform - GV reflectivity threshold at/below which GV data are considered
;                to be of Stratiform Rain Type.  Default = 25.0 if not specified.
;                If set to <= 0, then GV reflectivity is ignored in evaluating
;                whether PR-indicated Convective Rain Type matches GV type.
;
; s2ku         - Binary parameter, controls whether or not to apply the Liao/
;                Meneghini S-band to Ku-band adjustment to GV reflectivity.
;                Default = no
;
; bbparms      - structure to hold computed bright band variables: mean BB
;                height, and lowest and highest fixed-layer heights affected by
;                the bright band (see heights parameter and DESCRIPTION section)
;              - All heights are in relation to Above Ground Level starting with
;                version 1.1 netCDF data files.
;
; bb_relative  - Binary parameter, controls whether or not to compute height
;                categories that are relative to the mean BB height (km above
;                or below) or relative to the earth surface (km above).
;                Default = no (Earth-surface-relative)
;
; bbwidth      - Height (km) above/below the mean bright band height within
;                which a sample touching (above) [below] this layer is
;                considered to be within (above) [below] the BB. Default=0.750
;
; alt_bb_hgt   - Either a single numerical value specifying the mean bright band
;                height to be used, or a file of precomputed freezing level
;                heights that will be searched to find the BB height for the
;                current site and orbit, when the mean BB height cannot be
;                determined using BB field values in the DPR data.
;
; forcebb      - Binary keyword.  If set, and if alt_bb_height is specified and a
;                valid value for the mean BB height is provided or can be located
;                in the file, then this BB height value will override any mean BB
;                height determined from the DPR data.
;
; (pointers)   - Optional keywords consisting of unassigned pointers created by
;                the calling routine.  These pointers are assigned to their
;                namesake DATA FIELDS at the end of the routine, as follows:
; 
; At the end of the procedure, the following data fields will be available
; to be returned to the caller.  If a pointer for the variable is provided
; in the parameter list, the pointer will be assigned to the variable.  Pointers
; passed as arguments should be unassigned pointers to an undefined variable,
; i.e., a heap pointer created as follows: thePointer=ptr_new(/allocate_heap).
; If no pointer is supplied for the keyword, then the corresponding data
; variable goes out of scope when this function returns to the caller, and the
; data field will be unavailable.
;
; mygeometa           structure holding dimension, version, and threshold
;                       information for the matchup data
; mysweeps            structure holding GR volume info - sweep elevations etc.
; mysite              structure holding GR location, station ID, etc.
; myflags             structure holding flags indicating whether data fields are
;                        good, or just fill values
; myfiles             structure holding the names of the input PR and GR files
;                        used in the matchup
;
; gvz                 subsetted array of volume-matched GR mean reflectivity
; gvzmax              subsetted array of volume-matched GR maximum reflectivity
; gvzstddev           subsetted array of volume-matched GR reflectivity standard
;                        deviation
;
; gvrc                subsetted array of volume-matched GR 3D mean RC rainrate
; gvrcmax             subsetted array of volume-matched GR 3D max. RC rainrate
; gvrcstddev          subsetted array of volume-matched GR 3D RC rainrate
;                        standard deviation
;
; gvrp                subsetted array of volume-matched GR 3D mean RP rainrate
; gvrpmax             subsetted array of volume-matched GR 3D max. RP rainrate
; gvrpstddev          subsetted array of volume-matched GR 3D RP rainrate
;                        standard deviation
;
; gvrr                subsetted array of volume-matched GR 3D mean RR rainrate
; gvrrmax             subsetted array of volume-matched GR 3D max. RR rainrate
; gvrrstddev          subsetted array of volume-matched GR 3D RR rainrate
;                        standard deviation
;
; GR_DP_Zdr           subsetted array of volume-matched GR mean Zdr
;                        (differential reflectivity)
; GR_DP_ZdrMax        As above, but sample maximum of Zdr
; GR_DP_ZdrStdDev     As above, but sample standard deviation of Zdr
;
; GR_DP_Kdp           subsetted array of volume-matched GR mean Kdp (specific
;                        differential phase)
; GR_DP_KdpMax        As above, but sample maximum of Kdp
; GR_DP_KdpStdDev     As above, but sample standard deviation of Kdp
;
; GR_DP_RHOhv         subsetted array of volume-matched GR mean RHOhv
;                        (co-polar correlation coefficient)
; GR_DP_RHOhvMax      As above, but sample maximum of RHOhv
; GR_DP_RHOhvStdDev   As above, but sample standard deviation of RHOhv
;
; GR_DP_HID           subsetted array of volume-matched GR Hydrometeor ID (HID)
;                         category (count of GR bins in each HID category)
; mode_HID           subsetted array of volume-matched GR Hydrometeor ID (HID)
;                         "best" category (HID category with the highest count
;                         of bins in the sample volume)
;
; GR_DP_Dzero         subsetted array of volume-matched GR mean D0 (Median
;                        volume diameter)
; GR_DP_DzeroMax      As above, but sample maximum of Dzero
; GR_DP_DzeroStdDev   As above, but sample standard deviation of Dzero
;
; GR_DP_Nw            subsetted array of volume-matched GR mean Nw (Normalized
;                        intercept parameter)
; GR_DP_NwMax         As above, but sample maximum of Nw
; GR_DP_NwStdDev      As above, but sample standard deviation of Nw
;
; zraw                subsetted array of volume-match DPR measured reflectivity
; zcor                subsetted array of volume-match DPR corrected reflectivity
; rain3               subsetted array of volume-match DPR 3D rainrate
; top                 subsetted array of volume-match sample top heights, km
; botm                subsetted array of volume-match sample bottom heights, km
; lat                 subsetted array of volume-match sample latitude
; lon                 subsetted array of volume-match sample longitude
; nearSurfRain        subsetted array of volume-match near-surface PR rainrate *
; nearSurfRain_Comb   subsetted array of volume-matched 2BDPRGMI rainrate *
; pia *               subsetted array of DPR Path Integrated Attenuation
; pr_index            subsetted array of 1-D indices of the original (scan,ray)
;                        PR product coordinates *
; rnFlag              subsetted array of volume-match sample point yes/no rain
;                        flag value *
; rnType              subsetted array of volume-match sample point rain type *,#
; XY_km               array of volume-match sample point X and Y coordinates,
;                        radar-centric, km *
; dist                array of volume-match sample point range from radar, km *
; hgtcat              array of volume-match sample point height layer indices,
;                        0-12, representing 1.5-19.5 km
; bbProx              array of volume-match sample point proximity to mean
;                        bright band:
;                     1 (below), 2 (within), 3 (above)
; bbHeight            array of PR 2A25 bright band height from RangeBinNums, m *
; bbStatus            array of PR 2A23 bright band status *
; status_2a23         array of PR 2A23 status flag *
; pctgoodpr           array of volume-match sample point percent of original
;                        PR dBZ bins above threshold
; pctgoodgv           array of volume-match sample point percent of original
;                        GR dBZ bins above threshold
; pctgoodrain         array of volume-match sample point percent of original
;                        PR rainrate bins above threshold
; pctgoodrrgv         array of volume-match sample point percent of original
;                        GR rainrate bins above threshold
;
; The arrays should all be of the same size when done, with the exception of
; the xCorner and yCorner fields that have an additional dimension that
; needs to be dealt with.  Those marked by * are originally single-level fields
; like nearSurfRain that are replicated to the N sweep levels in the volume scan
; to match the multi-level fields before the data get subsetted. Subsetting
; involves paring off the "bogus" data points that enclose the area of the
; actual DPR/GR overlap data.
;
; # indicates that rain type is dumbed down to simple categories 1 (Stratiform),
; 2 (Convective), or 3 (Other), from the original PR 3-digit subcategories
;
;
; HISTORY
; -------
; 07/17/13 Morris, GPM GV, SAIC
; - Created from fprep_geo_match_profiles.pro
; 07/24/13 by Bob Morris, GPM GV (SAIC)
;  - Added rrgvMean, rrgvMax, rrgvStdDev, and pctgoodrrgv to the list of
;    parameters able to be read and/or computed, and returned.
; 04/28/14 by Bob Morris, GPM GV (SAIC)
;  - Changed handling of case where no stratiform points with defined BB heights
;    exist to not exit with failed status.
; 06/06/14 by Bob Morris, GPM GV (SAIC)
;  - Added retrieval of Mean, Max, StdDev, and "n_rejected" flavors of the GR
;    dual-polarization variables HID, D0, Nw, Zdr, Kdp, and RHOhv.
; 06/24/14 Morris, GPM GV, SAIC
; - Added capability to specify a mean bright band height to be used if one
;   cannot be extracted from the DPR bright band field in the matchup files.
; 6/27/14 by Bob Morris, GPM GV (SAIC)
;  - Added reading of new DPR variables Dm, Nw, and their n_rejected values.
; 7/8/14 by Bob Morris, GPM GV (SAIC)
;  - Added check of supplied heights array values to make sure they meet the
;    expected criteria.
;  - Modified assignment of hgtcat so that all locations with beam heights above
;    0.0 km are assigned a height category, and those below the lowest layer but
;    above 0.0 km are assigned a hgtcat value of -1.  Changed hgtcat value for
;    samples above the highest fixed layer from -1 to -2 to distinguish them
;    from the too-low category.
;  - Fixed the assignment of BB proximity so that only locations with above 0.0
;    top and bottom heights are assigned.  Those with 0.0 heights are left
;    initialized in the Unknown BB category rather than below-BB.
; 11/04/14 by Bob Morris, GPM GV (SAIC)
;  - Added processing of GR RC and RP rainrate fields for version 1.1 file.
; 11/26/14 by Bob Morris, GPM GV (SAIC)
;  - Added capability for alt_bb_height to be either a single numerical value
;    as it already was, or the pathname to a file to be searched to find the
;    alternate BB height value (see function get_ruc_bb.pro).
; 03/31/14 by Bob Morris, GPM GV (SAIC)
;  - Added capability to accept string representation of a numerical value for
;    alt_bb_hgt and convert it to numerical type.  Calls new utility function
;    is_a_number().
; 04/14/15 by Bob Morris, GPM GV (SAIC)
;  - Added PIA and StormTopHeight as variables to be read from the version 1.1
;    matchup files.
; 04/23/15 by Bob Morris, GPM GV (SAIC)
;  - Added logic to Catch errors in reading matchup netCDF files such that the
;    program does not crash and exit when read errors occur, leaving behind the
;    temporary copy of the file.
; 08/17/15 by Bob Morris, GPM GV (SAIC)
;  - Added FORCEBB parameter to override the DPR mean BB height with the value
;    provided by ALT_BB_HEIGHT.
; 09/04/15 by Bob Morris, GPM GV (SAIC)
;  - Added keyword parameter RAY_RANGE to specify DPR rays to clip to the
;    returned data (i.e., inner swath band of data, or two outer swath bands).
;  - Moved BB calculations up to the front so that if we have to quit because of
;    a no-BB situation we do so right away.  Also, so that when clipping to a
;    range of ray numbers we process the unclipped data first to avoid missing
;    valid BB points from the lost regions.
;
; EMAIL QUESTIONS OR COMMENTS TO:
;       <Bob Morris> kenneth.r.morris@nasa.gov
;       <Matt Schwaller> mathew.r.schwaller@nasa.gov
;-
;===============================================================================


FUNCTION fprep_dpr_geo_match_profiles, ncfilepr, heights_in, $
    PCT_ABV_THRESH=pctAbvThresh, GV_CONVECTIVE=gvconvective, $
    GV_STRATIFORM=gvstratiform, S2KU=s2ku, PTRgeometa=ptr_geometa, $
    PTRsweepmeta=ptr_sweepmeta, PTRsitemeta=ptr_sitemeta, $
    PTRfieldflags=ptr_fieldflags, PTRfilesmeta=ptr_filesmeta, $

   ; ground radar variables
    PTRGVZMEAN=ptr_gvz, PTRGVMAX=ptr_gvzmax, PTRGVSTDDEV=ptr_gvzstddev, $
    PTRGVRCMEAN=ptr_gvrc, PTRGVRCMAX=ptr_gvrcmax, PTRGVRCSTDDEV=ptr_gvrcstddev,$
    PTRGVRPMEAN=ptr_gvrp, PTRGVRPMAX=ptr_gvrpmax, PTRGVRPSTDDEV=ptr_gvrpstddev,$
    PTRGVRRMEAN=ptr_gvrr, PTRGVRRMAX=ptr_gvrrmax, PTRGVRRSTDDEV=ptr_gvrrstddev,$
    PTRGVHID=ptr_GR_DP_HID, PTRGVMODEHID=ptr_mode_HID, PTRGVDZEROMEAN=ptr_GR_DP_Dzero, $
    PTRGVDZEROMAX=ptr_GR_DP_Dzeromax, PTRGVDZEROSTDDEV=ptr_GR_DP_Dzerostddev, $
    PTRGVNWMEAN=ptr_GR_DP_Nw, PTRGVNWMAX=ptr_GR_DP_Nwmax, $
    PTRGVNWSTDDEV=ptr_GR_DP_Nwstddev, PTRGVZDRMEAN=ptr_GR_DP_Zdr, $
    PTRGVZDRMAX=ptr_GR_DP_Zdrmax, PTRGVZDRSTDDEV=ptr_GR_DP_Zdrstddev, $
    PTRGVKDPMEAN=ptr_GR_DP_Kdp, PTRGVKDPMAX=ptr_GR_DP_Kdpmax, $
    PTRGVKDPSTDDEV=ptr_GR_DP_Kdpstddev, PTRGVRHOHVMEAN=ptr_GR_DP_RHOhv, $
    PTRGVRHOHVMAX=ptr_GR_DP_RHOhvmax, PTRGVRHOHVSTDDEV=ptr_GR_DP_RHOhvstddev, $

   ; space radar variables
    PTRzcor=ptr_zcor, PTRzraw=ptr_zraw, PTRrain3d=ptr_rain3, $
    PTRdprdm=ptr_dprDm, PTRdprnw=ptr_dprNw, $
    PTRprlat=ptr_dpr_lat, PTRprlon=ptr_dpr_lon, PTRpia=ptr_pia, $
    PTRsfcrainpr=ptr_nearSurfRain, PTRsfcraincomb=ptr_nearSurfRain_Comb, $
    PTRrainflag_int=ptr_rnFlag, PTRraintype_int=ptr_rnType, $
    PTRlandOcean_int=ptr_landOcean, PTRpridx_long=ptr_pr_index, $
    PTRstmTopHgt=ptr_stmTopHgt, PTRbbHgt=ptr_bbHeight, PTRbbStatus=ptr_bbstatus, $

   ; derived/computed variables
    PTRtop=ptr_top, PTRbotm=ptr_botm, PTRlat=ptr_lat, PTRlon=ptr_lon, $
    PTRxCorners=ptr_xCorner, PTRyCorners=ptr_yCorner, PTRbbProx=ptr_bbProx, $
    PTRclutterStatus=ptr_clutterStatus, PTRhgtcat=ptr_hgtcat, PTRdist=ptr_dist,$

   ; percent above threshold parameters
    PTRpctgoodpr=ptr_pctgoodpr, PTRpctgoodrain=ptr_pctgoodrain, $
    PTRpctgoodDprDm=ptr_pctgoodDprDm, PTRpctgoodDprNw=ptr_pctgoodDprNw, $
    PTRpctgoodgv=ptr_pctgoodgv, PTRpctgoodrcgv=ptr_pctgoodrcgv, $
    PTRpctgoodrpgv=ptr_pctgoodrpgv, PTRpctgoodrrgv=ptr_pctgoodrrgv, $
    PTRpctgoodhidgv=ptr_pctgoodhidgv, PTRpctgooddzerogv=ptr_pctgooddzerogv, $
    PTRpctgoodnwgv=ptr_pctgoodnwgv, PTRpctgoodzdrgv=ptr_pctgoodzdrgv, $
    PTRpctgoodkdpgv=ptr_pctgoodkdpgv, PTRpctgoodrhohvgv=ptr_pctgoodrhohvgv, $

   ; Bright Band structure, control parameters
    BBPARMS=bbparms, BB_RELATIVE=bb_relative, BBWIDTH=bbwidth, $
    ALT_BB_HGT=alt_bb_hgt, FORCEBB=forcebb, $

   ; ray number range limits parameter (2 element int array)
    RAY_RANGE=ray_range

; "include" file for structs returned from read_dpr_geo_match_netcdf()
;@dpr_geo_match_nc_structs.inc  ; instead, call GET_DPR_GEO_MATCH_NC_STRUCT()

; "include" file for PR data constants
@dpr_params.inc

status = 1   ; init return status to FAILED

s2ku = keyword_set( s2ku )

nrayrange = N_ELEMENTS(ray_range)
CASE nrayrange OF
      0 : clipByRay = 0
      2 : BEGIN
             clipByRay = 1
            ; we don't know how many rays in the product yet, so we can't
            ; check the ray_range values for validity
             IF ray_range[0] GT ray_range[1] THEN BEGIN
               ; clip to two bands: 0->ray_range[1] and ray_range[0]->NRAYSPERSCAN
                inside_clip = 0
             ENDIF ELSE BEGIN
               ; clip to inner band: ray_range[0] -> ray_range[1]
                inside_clip = 1
             ENDELSE
          END
   ELSE : BEGIN
             message, "Illegal RAY_RANGE specification, expect INTARR(2)", /INFO
             GOTO, errorExit
          END
ENDCASE

; if convective or stratiform reflectivity thresholds are not specified, disable
; rain type overrides by setting values to zero
IF ( N_ELEMENTS(gvconvective) NE 1 ) THEN gvconvective=0.0
IF ( N_ELEMENTS(gvstratiform) NE 1 ) THEN gvstratiform=0.0

IF ( N_ELEMENTS(heights_in) EQ 0 ) THEN BEGIN
   print, "In fprep_dpr_geo_match_profiles(): assigning 13 default height ", $
          "levels, 1.5-19.5km"
   heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
   halfdepth=(heights[1]-heights[0])/2.0
ENDIF ELSE BEGIN
  ; we expect an array of equally-spaced heights, where the first height is
  ; equal to the step between heights
   heights=heights_in
   depth=(heights[1]-heights[0])
;TEMPORARY OVERRIDE TO GET THIS TO RUN FOR BB_REL SITUATION
halfdepth=depth/2.0
;   hgtcheck = (INDGEN(N_ELEMENTS(heights))+1)*depth
;   IF ARRAY_EQUAL(heights,hgtcheck) THEN halfdepth=depth/2.0 $
;   ELSE BEGIN
;      PRINT, "Supplied heights array values not monospaced or first value ", $
;             "not equal to height step."
;      PRINT, "Supplied heights: ", heights_in
;      PRINT, "Expected heights: ", hgtcheck
;      GOTO, errorExit
;   ENDELSE
ENDELSE

; Get an uncompressed copy of the netCDF file - we never touch the original
cpstatus = uncomp_file( ncfilepr, ncfile1 )

if (cpstatus eq 'OK') then begin

 ; create <<initialized>> structures to hold the metadata variables
  mygeometa=GET_DPR_GEO_MATCH_NC_STRUCT('matchup')  ;{ dpr_geo_match_meta }
  mysweeps=GET_DPR_GEO_MATCH_NC_STRUCT('sweeps')    ;{ gr_sweep_meta }
  mysite=GET_DPR_GEO_MATCH_NC_STRUCT('site')        ;{ gr_site_meta }
  myflags=GET_DPR_GEO_MATCH_NC_STRUCT('fields')     ;{ dpr_gr_field_flags }
  myfiles=GET_DPR_GEO_MATCH_NC_STRUCT( 'files' )

 ; read the file to populate only the structures
   CATCH, error
   IF error EQ 0 THEN BEGIN
      status = read_dpr_geo_match_netcdf( ncfile1, matchupmeta=mygeometa, $
        sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, filesmeta=myfiles )
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
      status=1   ;return, -1
   ENDELSE
   Catch, /Cancel

 ; Now check NUMRAYSPERSCAN against ray_range values, if clipping to
 ; a range of rays
  IF clipbyray THEN BEGIN
     DPR_scantype = mygeometa.DPR_scantype
     CASE STRUPCASE(DPR_scantype) OF
        'HS' : BEGIN
                  RAYSPERSCAN = RAYSPERSCAN_HS
                  GATE_SPACE = BIN_SPACE_HS
               END
        'MS' : BEGIN
                  RAYSPERSCAN = RAYSPERSCAN_MS
                  GATE_SPACE = BIN_SPACE_NS_MS
              END
        'NS' : BEGIN
                  RAYSPERSCAN = RAYSPERSCAN_NS
                  GATE_SPACE = BIN_SPACE_NS_MS
               END
        ELSE : message, "Illegal scan type '"+DPR_scantype+"'"
     ENDCASE
     IF MAX(ray_range) GT RAYSPERSCAN THEN BEGIN
       ; delete file copy here, we are completely exiting with an error, 
       ; user needs to fix the ray_range values that are out of line with
       ; the data files being processed
        command3 = "rm -v " + ncfile1
        spawn, command3
        PRINT, ''
        PRINT, "RAYSPERSCAN in " + DPR_scantype + " scans: ", RAYSPERSCAN
        PRINT, "Requested ray range: ", ray_range
        message, "Requested ray_range exceeds number of rays in product."
     ENDIF
  ENDIF

 ; remove the netCDF file copy and exit, if problems reading file
  IF (status EQ 1) THEN BEGIN
     command3 = "rm -v " + ncfile1
     spawn, command3
     GOTO, errorExit
  ENDIF

  site_lat = mysite.site_lat
  site_lon = mysite.site_lon
  siteID = string(mysite.site_id)
  site_elev = mysite.site_elev

 ; now create data field arrays of correct dimensions and read ALL data fields

  nfp = mygeometa.num_footprints  ; # of PR rays in dataset (real+bogus)
  nswp = mygeometa.num_sweeps     ; # of GR elevation sweeps in dataset
  nc_file_version = mygeometa.nc_file_version   ; geo-match file version

  gvexp=intarr(nfp,nswp)          ; Expected/Rejected Bin Count variables
  gvrej=intarr(nfp,nswp)
  IF nc_file_version GT 1.0 THEN BEGIN
     gvrcrej=intarr(nfp,nswp)
     gvrprej=intarr(nfp,nswp)
  ENDIF
  gvrrrej=intarr(nfp,nswp)
  gv_zdr_rej=intarr(nfp,nswp)
  gv_kdp_rej=intarr(nfp,nswp)
  gv_rhohv_rej=intarr(nfp,nswp)
  gv_hid_rej=intarr(nfp,nswp)
  gv_dzero_rej=intarr(nfp,nswp)
  gv_nw_rej=intarr(nfp,nswp)
  prexp=intarr(nfp,nswp)
  zrawrej=intarr(nfp,nswp)
  zcorrej=intarr(nfp,nswp)
  rainrej=intarr(nfp,nswp)
  dpr_dm_rej=intarr(nfp,nswp)
  dpr_nw_rej=intarr(nfp,nswp)

  gvz=fltarr(nfp,nswp)            ; Ground Radar variables
  gvzmax=fltarr(nfp,nswp)
  gvzstddev=fltarr(nfp,nswp)
  IF nc_file_version GT 1.0 THEN BEGIN
     gvrc=fltarr(nfp,nswp)
     gvrcMax=fltarr(nfp,nswp)
     gvrcStdDev=fltarr(nfp,nswp)
     gvrp=fltarr(nfp,nswp)
     gvrpMax=fltarr(nfp,nswp)
     gvrpStdDev=fltarr(nfp,nswp)
  ENDIF
  gvrr=fltarr(nfp,nswp)
  gvrrMax=fltarr(nfp,nswp)
  gvrrStdDev=fltarr(nfp,nswp)
  ; can't define GR_DP_HID unless num_HID_categories is non-zero
  GR_DP_HID=intarr(mygeometa.num_HID_categories,nfp,nswp)
  GR_DP_Zdr=fltarr(nfp,nswp)
  GR_DP_ZdrMax=fltarr(nfp,nswp)
  GR_DP_ZdrStdDev=fltarr(nfp,nswp)
  GR_DP_Kdp=fltarr(nfp,nswp)
  GR_DP_KdpMax=fltarr(nfp,nswp)
  GR_DP_KdpStdDev=fltarr(nfp,nswp)
  GR_DP_RHOhv=fltarr(nfp,nswp)
  GR_DP_RHOhvMax=fltarr(nfp,nswp)
  GR_DP_RHOhvStdDev=fltarr(nfp,nswp)
  GR_DP_Dzero=fltarr(nfp,nswp)
  GR_DP_DzeroMax=fltarr(nfp,nswp)
  GR_DP_DzeroStdDev=fltarr(nfp,nswp)
  GR_DP_Nw=fltarr(nfp,nswp)
  GR_DP_NwMax=fltarr(nfp,nswp)
  GR_DP_NwStdDev=fltarr(nfp,nswp)

  zraw=fltarr(nfp,nswp)           ; DPR variables
  zcor=fltarr(nfp,nswp)
  rain3=fltarr(nfp,nswp)
  dpr_Dm=fltarr(nfp,nswp)
  dpr_Nw=fltarr(nfp,nswp)
  dpr_lat=fltarr(nfp)
  dpr_lon=fltarr(nfp)
  IF nc_file_version GT 1.0 THEN BEGIN
     pia=fltarr(nfp)
     stmTopHgt=intarr(nfp)
  ENDIF
  bbHeight=fltarr(nfp)
  nearSurfRain=fltarr(nfp)
  nearSurfRain_Comb=fltarr(nfp)
  rnflag=intarr(nfp)
  rntype=intarr(nfp)
  landoceanflag=intarr(nfp)
  bbStatus=intarr(nfp)

  clutterStatus=intarr(nfp)       ; derived variables
  top=fltarr(nfp,nswp)
  botm=fltarr(nfp,nswp)
  lat=fltarr(nfp,nswp)
  lon=fltarr(nfp,nswp)
  pr_index=lonarr(nfp)
  xcorner=fltarr(4,nfp,nswp)
  ycorner=fltarr(4,nfp,nswp)


   CATCH, error
   IF error EQ 0 THEN BEGIN
    status = read_dpr_geo_match_netcdf(ncfile1,                                $

   ; expected/rejected bin counts for percent above threshold calculations:
    gvexpect_int=gvexp, gvreject_int=gvrej, dprexpect_int=prexp,               $
    zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej,    $
    dpr_dm_reject_int=dpr_dm_rej, dpr_nw_reject_int=dpr_nw_rej,                $
    gv_rc_reject_int=gvrcrej, gv_rp_reject_int=gvrprej,                        $
    gv_rr_reject_int=gvrrrej, gv_hid_reject_int=gv_hid_rej,                    $
    gv_dzero_reject_int=gv_dzero_rej, gv_nw_reject_int=gv_nw_rej,              $
    gv_zdr_reject_int=gv_zdr_rej, gv_kdp_reject_int=gv_kdp_rej,                $
    gv_RHOhv_reject_int=gv_RHOhv_rej,                                          $

   ; DPR and GR reflectivity and rainrate and GR dual-polarization derived
   ; variables at sweep levels:
    dbzgv=gvz, gvMax=gvzMax, gvStdDev=gvzStdDev, dbzcor=zcor, dbzraw=zraw,     $
    rcgvMean=gvrc, rcgvMax=gvrcMax, rcgvStdDev=gvrcStdDev,                     $
    rpgvMean=gvrp, rpgvMax=gvrpMax, rpgvStdDev=gvrpStdDev,                     $
    rrgvMean=gvrr, rrgvMax=gvrrMax, rrgvStdDev=gvrrStdDev,                     $
    rain3d=rain3, DmDPRmean=DPR_Dm, NwDPRmean=DPR_Nw,                          $
    zdrgvMean=GR_DP_Zdr, zdrgvMax=GR_DP_ZdrMax, zdrgvStdDev=GR_DP_ZdrStdDev,   $
    kdpgvMean=GR_DP_Kdp, kdpgvMax=GR_DP_KdpMax, kdpgvStdDev=GR_DP_KdpStdDev,   $
    RHOHVgvMean=GR_DP_RHOhv, RHOHVgvMax=GR_DP_RHOhvMax,                        $
    RHOHVgvStdDev=GR_DP_RHOhvStdDev, dzerogvMean=GR_DP_Dzero,                  $
    dzerogvMax=GR_DP_DzeroMax, dzerogvStdDev=GR_DP_DzeroStdDev,                $
    nwgvMean=GR_DP_Nw, nwgvMax=GR_DP_NwMax, nwgvStdDev=GR_DP_NwStdDev,         $
    hidgv=GR_DP_HID,                                                           $

   ; sample horizontal/vertical location variables:
    topHeight=top, bottomHeight=botm, xCorners=xCorner, yCorners=yCorner,      $
    latitude=lat, longitude=lon, DPRlatitude=DPR_lat, DPRlongitude=DPR_lon,    $

   ; surface-level DPR rainrate variables and misc. footprint characteristics:
    sfcraindpr=nearSurfRain, sfcraincomb=nearSurfRain_Comb, bbhgt=BBHeight,    $
    rainflag_int=rnFlag, raintype_int=rnType, sfctype_int=landOceanFlag,       $
    piaFinal=pia, heightStormTop_int=stmTopHgt,                                $
    clutterStatus_int=clutterStatus, BBstatus_int=bbStatus, pridx_long=pr_index)
   ENDIF ELSE BEGIN
      help,!error_state,/st
      Catch, /Cancel
      message, 'err='+STRING(error)+", "+!error_state.msg, /INFO
      status=1   ;return, -1
   ENDELSE
   Catch, /Cancel

 ; remove the uncompressed file copy
  command3 = "rm -v " + ncfile1
  spawn, command3
  IF (status EQ 1) then GOTO, errorExit

endif else begin

  print, 'Cannot copy/unzip netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit

endelse

; get array indices of the non-bogus (i.e., "actual") PR footprints
; -- pr_index is defined for one slice (sweep level), while most fields are
;    multiple-level (have another dimension: nswp).  Deal with this later on.
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   status = 1
   goto, errorExit
endif

; Clip single-level fields we will use for mean BB calculations:
BB = BBHeight[idxpractual]
bbStatusCode = bbStatus[idxpractual]
bbraintype = rnType[idxpractual]

; if we are clipping the data to a range of rays, then find the
; corresponding pr_index values, otherwise just get the subset of
; pr_index values for actual PR rays in the matchup
IF clipByRay THEN BEGIN
   pridx2get = pr_index[idxpractual]
  ; analyze the pr_index, decomposed into DPR-product-relative scan and ray number
   raypr = (pridx2get MOD RAYSPERSCAN)+1   ; 1-based ray numbers
   scanpr = (pridx2get/RAYSPERSCAN)+1      ; "" for scan numbers
   IF inside_clip THEN idxclipped = WHERE( raypr GE ray_range[0] $
          AND raypr LE ray_range[1], countclipped ) $
   ELSE idxclipped = WHERE( raypr GE ray_range[0] $
          OR raypr LE ray_range[1], countclipped )
   IF countclipped GT 0 THEN BEGIN
      idxpractualCopy = idxpractual
      idxpractual = idxpractualCopy[idxclipped]
      countactual = countclipped
   ENDIF ELSE BEGIN
      print, "No data points in ray range limits, quitting case."
      status = 1
      goto, errorExit
   ENDELSE
ENDIF ;ELSE pr_idx_actual = pr_index[idxpractual]

; re-set the number of footprints in the geo_match_meta structure to the
; subsetted value
mygeometa.num_footprints = countactual

; - - - - - - - - - - - - - - - - - - - - - - - -

; convert bright band heights from m to km, where defined, and get mean BB hgt.
; - first, find the indices of stratiform rays with BB defined

idxbbdef = where(bb GT 0.0 AND bbrainType EQ 1, countBB)
IF ( countBB GT 0 ) THEN BEGIN
  ; grab the subset of BB values for defined/stratiform
   bb2hist = bb[idxbbdef]/1000.  ; with conversion to km

   bs=0.2  ; bin width, in km, for HISTOGRAM in get_mean_bb_height()
;   hist_window = 9  ; uncomment to plot BB histogram and print diagnostics

  ; - now, do some sorcery to find the best mean BB height estimate, in km
;print, "myflags.have_BBstatus: ", myflags.have_BBstatus
   IF myflags.have_BBstatus EQ 1 THEN BEGIN
     ; try to get mean BB using BBstatus of 'good' or 'fair'
      bbstatusstrat = bbStatusCode[idxbbdef]
      meanbb_MSL = get_mean_bb_height( bb2hist, bbstatusstrat, BS=bs, $
                                       HIST_WINDOW=hist_window )
   ENDIF ELSE BEGIN
     ; use histogram analysis of BB heights to get mean height
      meanbb_MSL = get_mean_bb_height( bb2hist, BS=bs, HIST_WINDOW=hist_window )
   ENDELSE
ENDIF

IF ( countBB LE 0 AND N_ELEMENTS(alt_bb_hgt) EQ 1 ) $
OR ( N_ELEMENTS(alt_bb_hgt) EQ 1 AND KEYWORD_SET(forcebb) ) THEN BEGIN
  ; i.e., if we have the alt_bb_height option, and either we didn't find a
  ; DPR-based BB height or are forcing the use of alt_bb_height
   meanbb_MSL = -99.99   ; reset DPR-based BB height, if any
   meanbb = -99.99
   message, "Using ALT_BB_HGT value to assign mean BB height.", /info
   sz_alt_bb = FIX( SIZE(alt_bb_hgt, /TYPE) )
   SWITCH sz_alt_bb OF
         1 :
         2 :
         3 :
         4 :
         5 : BEGIN
                meanbb_MSL = FLOAT(alt_bb_hgt)
                BREAK
             END
         7 : BEGIN
                IF FILE_TEST( alt_bb_hgt, /READ ) EQ 1 THEN BEGIN
                   parsed = STRSPLIT(FILE_BASENAME(ncfilepr), '.', /extract )
                   orbit = parsed[3]
                   ; try to get the mean BB for this case from the alt_bb_hgt
                   ; file, using input value of meanbb in bbparms structure as
                   ; the default missing value if it fails to find a match
                   meanbb_MSL = get_ruc_bb( alt_bb_hgt, siteID, orbit, $
                                            MISSING=-99.99, /VERBOSE )
                ENDIF ELSE BEGIN
                   ; check whether we were suppied a number as a string, 
                   ; and if so, convert it to float and use the value
                   IF is_a_number(alt_bb_hgt) THEN BEGIN
                      message, "Converting alt_bb_hgt string '" + alt_bb_hgt + $
                               "' to numerical value", /INFO
                      meanbb_MSL=FLOAT(alt_bb_hgt[0])   ; take first value if array
                   ENDIF ELSE BEGIN
                      print, ''
                      message, "Cannot find/read/convert alt_bb_hgt: "+alt_bb_hgt, /INFO
                      print, ''
                   ENDELSE
                ENDELSE
                BREAK
             END
         ELSE : BEGIN
                print, ''
                message, "Illegal type for alt_bb_hgt:", /INFO
                help, alt_bb_hgt
                print, ''
             END
   ENDSWITCH
ENDIF ELSE BEGIN
  ; if we didn't find a DPR-based BB height and have no alt_bb_height option
   IF countBB LE 0 THEN BEGIN
      meanbb_MSL = -99.99
      meanbb = -99.99
      message, "No valid bright band heights for case, "+ $
               "unable to populate bbparms structure.", /INFO
   ENDIF
ENDELSE

IF keyword_set(bb_relative) AND meanbb_MSL LE -99.9 THEN BEGIN
   message, "BB_RELATIVE option requested but cannot compute "+ $
            "BB-relative heights, quitting.", /INFO
   status = 1   ; set to FAILED
   goto, errorExit
ENDIF

IF meanbb_MSL GT 0.0 THEN BEGIN
  ; BB height in netCDF file is height above MSL -- must adjust mean BB to
  ; height above ground level for comparison to "heights", but don't let it go
  ; to or below below 0.0 km
   meanbb = (meanbb_MSL - site_elev) > 0.001

   IF keyword_set(bb_relative) THEN BEGIN
     ; level affected by BB is simply the zero-height BB-relative layer
      idxBB_HgtHi = WHERE( heights EQ 0.0, nbbzero)
      IF nbbzero EQ 1 THEN BEGIN
         BB_HgtHi = idxBB_HgtHi
         BB_HgtLo = BB_HgtHi
      ENDIF ELSE BEGIN
         print, "ERROR assigning BB-affected layer number."
         status = 1   ; set to FAILED
         goto, errorExit
      ENDELSE
   ENDIF ELSE BEGIN
     ; Level below BB is affected if layer top is 500m (0.5 km) or less
     ; below BB_Hgt, so BB_HgtLo is index of lowest fixed-height layer
     ; considered to be within the BB(see 'heights' array and halfdepth, above)
      idxbelowbb = WHERE( (heights+halfdepth) LT (meanbb-0.5), countbelowbb )
      if (countbelowbb GT 0) then $
           BB_HgtLo = (MAX(idxbelowbb) + 1) < (N_ELEMENTS(heights)-1) $
      else BB_HgtLo = 0
     ; Level above BB is affected if BB_Hgt is 500m or less below layer bottom,
     ; so BB_HgtHi is highest fixed-height layer considered to be within the BB
      idxabvbb = WHERE( (heights-halfdepth) GT (meanbb+0.5), countabvbb )
      if (countabvbb GT 0) THEN BB_HgtHi = (MIN(idxabvbb) - 1) > 0 $
      else if (meanbb GE (heights(N_ELEMENTS(heights)-1)-halfdepth) ) then $
      BB_HgtHi = (N_ELEMENTS(heights)-1) else BB_HgtHi = 0
   ENDELSE

   IF (N_ELEMENTS(bbparms) EQ 1) THEN BEGIN
      bbparms.meanbb = meanbb
      bbparms.BB_HgtLo = BB_HgtLo < BB_HgtHi
      bbparms.BB_HgtHi = BB_HgtHi > BB_HgtLo
      print, 'Mean BB (km AGL), bblo, bbhi = ', meanbb, $
             heights[0]+halfdepth*2*bbparms.BB_HgtLo, $
             heights[0]+halfdepth*2*bbparms.BB_HgtHi
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; clip the data fields down to the actual footprint points.  Deal with the
; single-level vs. multi-level fields by replicating the single-level
; fields 'nswp' times

; build an array index of actual points, replicated over all the sweep levels
idx3d=long(gvexp)           ; take one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L             ; re-set all point values to 0
idx3d[idxpractual,0] = 1L   ; set first-sweep-level values to 1 where non-bogus

; now copy the first sweep values to the other levels, and while in the same
; loop, make the single-level arrays for categorical fields the same dimension
; as the sweep-level by array concatenation
IF ( nswp GT 1 ) THEN BEGIN
   dpr_latApp = dpr_lat
   dpr_lonApp = dpr_lon  
   rnFlagApp = rnFlag
   rnTypeApp = rnType
   nearSurfRainApp = nearSurfRain
   nearSurfRain_CombApp = nearSurfRain_Comb
   pr_indexApp = pr_index
   bbStatusApp=bbStatus
   clutterStatusApp=clutterStatus
   BBHeightApp=BBHeight
   landOceanFlagApp=landOceanFlag
   IF nc_file_version GT 1.0 THEN BEGIN
      piaAPP=pia
      stmTopHgtAPP=stmTopHgt
   ENDIF

   FOR iswp=1, nswp-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]    ; copy first level values to iswp'th level
      ; concatenate another level's worth for PR Lat:
      dpr_lat = [dpr_lat, dpr_latApp]
      dpr_lon = [dpr_lon, dpr_lonApp]  ; ditto for PR lon
      rnFlag = [rnFlag, rnFlagApp]  ; ditto for rain flag
      rnType = [rnType, rnTypeApp]  ; ditto for rain type
      nearSurfRain = [nearSurfRain, nearSurfRainApp]  ; ditto for sfc rain
      ; ditto for DPR/GMI combined sfc rain:
      nearSurfRain_Comb = [nearSurfRain_Comb, nearSurfRain_CombApp]
      pr_index = [pr_index, pr_indexApp]                 ; ditto for pr_index
      bbStatus = [bbStatus, bbStatusApp]                 ; ditto for bbStatus
      clutterStatus = [clutterStatus, clutterStatusApp]  ; "" for clutterStatus
      BBHeight = [BBHeight, BBHeightApp]                 ; ditto for BBHeight
      landOceanFlag = [landOceanFlag, landOceanFlagApp]  ; "" landOceanFlag
      IF nc_file_version GT 1.0 THEN BEGIN
         pia = [pia, piaApp]                             ; "" piaFinal
         stmTopHgt = [stmTopHgt, stmTopHgtApp]           ; "" stormTopHeight
      ENDIF
   ENDFOR
ENDIF

; get the indices of all the non-bogus points in the 2D sweep-level arrays
idxpractual2d = where( idx3d EQ 1L, countactual2d )
if (countactual2d EQ 0) then begin
  ; this shouldn't be able to happen
   print, "No non-bogus 2D data points, quitting case."
   status = 1   ; set to FAILED
   goto, errorExit
endif

; clip the sweep-level arrays to the locations of actual PR footprints only
gvexp = gvexp[idxpractual2d]
gvrej = gvrej[idxpractual2d]
prexp = prexp[idxpractual2d]
zrawrej = zrawrej[idxpractual2d]
zcorrej = zcorrej[idxpractual2d]
rainrej = rainrej[idxpractual2d]
dpr_dm_rej = dpr_dm_rej[idxpractual2d]
dpr_nw_rej = dpr_nw_rej[idxpractual2d]
gvz = gvz[idxpractual2d]
gvzmax = gvzmax[idxpractual2d]
gvzstddev = gvzstddev[idxpractual2d]
IF nc_file_version GT 1.0 THEN BEGIN
   gvrc = gvrc[idxpractual2d]
   gvrcMax = gvrcMax[idxpractual2d]
   gvrcStdDev = gvrcStdDev[idxpractual2d]
   gvrp = gvrp[idxpractual2d]
   gvrpMax = gvrpMax[idxpractual2d]
   gvrpStdDev = gvrpStdDev[idxpractual2d]
ENDIF
gvrr = gvrr[idxpractual2d]
gvrrMax = gvrrMax[idxpractual2d]
gvrrStdDev = gvrrStdDev[idxpractual2d]
gv_zdr_rej = gv_zdr_rej[idxpractual2d]
gv_kdp_rej = gv_kdp_rej[idxpractual2d]
gv_rhohv_rej = gv_rhohv_rej[idxpractual2d]
gv_hid_rej = gv_hid_rej[idxpractual2d]
gv_dzero_rej = gv_dzero_rej[idxpractual2d]
gv_nw_rej = gv_nw_rej[idxpractual2d]
GR_DP_Zdr = GR_DP_Zdr[idxpractual2d]
GR_DP_Kdp = GR_DP_Kdp[idxpractual2d]
GR_DP_RHOhv = GR_DP_RHOhv[idxpractual2d]
GR_DP_Dzero = GR_DP_Dzero[idxpractual2d]
GR_DP_Nw = GR_DP_Nw[idxpractual2d]
GR_DP_ZdrMax = GR_DP_ZdrMax[idxpractual2d]
GR_DP_KdpMax = GR_DP_KdpMax[idxpractual2d]
GR_DP_RHOhvMax = GR_DP_RHOhvMax[idxpractual2d]
GR_DP_DzeroMax = GR_DP_DzeroMax[idxpractual2d]
GR_DP_NwMax = GR_DP_NwMax[idxpractual2d]
GR_DP_ZdrStdDev = GR_DP_ZdrStdDev[idxpractual2d]
GR_DP_KdpStdDev = GR_DP_KdpStdDev[idxpractual2d]
GR_DP_RHOhvStdDev = GR_DP_RHOhvStdDev[idxpractual2d]
GR_DP_DzeroStdDev = GR_DP_DzeroStdDev[idxpractual2d]
GR_DP_NwStdDev = GR_DP_NwStdDev[idxpractual2d]
          ; deal with the GR_DP_HID array with the extra dimension, and while we
          ; are here, compute HID mode at each footprint
GR_DP_HIDnew = intarr(mygeometa.num_HID_categories, countactual, nswp)
mode_HID = intarr(countactual, nswp)  ; initializes to 0 (==MISSING)
FOR hicat = 0,mygeometa.num_HID_categories-1 DO BEGIN
   GR_DP_HIDnew[hicat,*,*] = GR_DP_HID[hicat,idxpractual,*]
ENDFOR
; if I could get IDL's MAX to work correctly, wouldn't need to do this
FOR ifp=0,countactual-1 DO BEGIN
  FOR iswp=0, nswp-1 DO BEGIN
    ; grab the HID histogram for one footprint, minus the MISSING category
     hidhistfp=REFORM( GR_DP_HIDnew[1:14,ifp,iswp] )
     maxhistfp=MAX(hidhistfp)  ; bin count of the most frequent category
    ; need at least one of the histogram categories to be non-zero, else
    ; this footprint is left as the Unclassified/Missing category (=0)
     IF maxhistfp GT 0 THEN BEGIN
       ; hooray, we have an assignable hydromet category!
        idxmodes=WHERE(hidhistfp EQ maxhistfp, modecount) ;index(es) of above
       ; take the first category where the bin count is the same as the max,
       ; ignoring ties between identical bin counts for other categories
       ; - add 1 to WHERE index to get HID category number (1,2,...10)
        IF modecount GT 0 THEN mode_HID[ifp,iswp] = idxmodes[0]+1
     ENDIF
  ENDFOR
ENDFOR

zraw = zraw[idxpractual2d]
zcor = zcor[idxpractual2d]
rain3 = rain3[idxpractual2d]
DPR_Dm = DPR_Dm[idxpractual2d]
DPR_Nw = DPR_Nw[idxpractual2d]
top = top[idxpractual2d]
botm = botm[idxpractual2d]
lat = lat[idxpractual2d]
lon = lon[idxpractual2d]
dpr_lat = dpr_lat[idxpractual2d]
dpr_lon = dpr_lon[idxpractual2d]
rnFlag = rnFlag[idxpractual2d]
rnType = rnType[idxpractual2d]
landOceanFlag = landOceanFlag[idxpractual2d]
nearSurfRain = nearSurfRain[idxpractual2d]
nearSurfRain_Comb = nearSurfRain_Comb[idxpractual2d]
bbStatus = bbStatus[idxpractual2d]
clutterStatus = clutterStatus[idxpractual2d]
BBHeight = BBHeight[idxpractual2d]
pr_index = pr_index[idxpractual2d]
IF nc_file_version GT 1.0 THEN BEGIN
   pia = pia[idxpractual2d]
   stmTopHgt = stmTopHgt[idxpractual2d]
ENDIF

; deal with the x- and y-corner arrays with the extra dimension
xcornew = fltarr(4, countactual, nswp)
ycornew = fltarr(4, countactual, nswp)
FOR icorner = 0,3 DO BEGIN
   xcornew[icorner,*,*] = xCorner[icorner,idxpractual,*]
   ycornew[icorner,*,*] = yCorner[icorner,idxpractual,*]
ENDFOR

; - - - - - - - - - - - - - - - - - - - - - - - -

; compute percent completeness of the volume averages

IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   print, "======================================", $
          "======================================="
   print, "Computing Percent Above Threshold for DPR", $
          " and GR Reflectivity and Rainrate."
   print, "======================================", $
          "======================================="
   pctgoodpr = fltarr( N_ELEMENTS(prexp) )
   pctgoodgv =  fltarr( N_ELEMENTS(prexp) )
   pctgoodrain = fltarr( N_ELEMENTS(prexp) )
   pctgoodDprDm = fltarr( N_ELEMENTS(prexp) )
   pctgoodDprNw = fltarr( N_ELEMENTS(prexp) )
   IF nc_file_version GT 1.0 THEN BEGIN
     ; deal with additional rainrate fields for file version > 1.0
      pctgoodrcgv =  fltarr( N_ELEMENTS(prexp) )
      pctgoodrpgv =  fltarr( N_ELEMENTS(prexp) )
   ENDIF
   pctgoodrrgv =  fltarr( N_ELEMENTS(prexp) )
   pctgoodzdrgv = fltarr( N_ELEMENTS(prexp) )
   pctgoodkdpgv = fltarr( N_ELEMENTS(prexp) )
   pctgoodRHOhvgv = fltarr( N_ELEMENTS(prexp) )
   pctgoodhidgv = fltarr( N_ELEMENTS(prexp) )
   pctgooddzerogv = fltarr( N_ELEMENTS(prexp) )
   pctgoodnwgv = fltarr( N_ELEMENTS(prexp) )
   idxexpgt0 = WHERE( prexp GT 0 AND gvexp GT 0, countexpgt0 )
   IF ( countexpgt0 EQ 0 ) THEN BEGIN
      print, "No valid volume-average points, quitting case."
      status = 1
      goto, errorExit
   ENDIF ELSE BEGIN
      pctgoodpr[idxexpgt0] = $
         100.0 * FLOAT( prexp[idxexpgt0]-zcorrej[idxexpgt0] ) / prexp[idxexpgt0]
      pctgoodgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0]-gvrej[idxexpgt0] ) / gvexp[idxexpgt0]
      pctgoodrain[idxexpgt0] = $
         100.0 * FLOAT( prexp[idxexpgt0]-rainrej[idxexpgt0] ) / prexp[idxexpgt0]
      IF myflags.HAVE_paramDSD EQ 1 THEN BEGIN
         pctgoodDprDm[idxexpgt0] = $
           100.0 * FLOAT( prexp[idxexpgt0]-dpr_dm_rej[idxexpgt0] ) / prexp[idxexpgt0]
         pctgoodDprNw[idxexpgt0] = $
           100.0 * FLOAT( prexp[idxexpgt0]-dpr_nw_rej[idxexpgt0] ) / prexp[idxexpgt0]
      ENDIF
      IF nc_file_version GT 1.0 THEN BEGIN
        ; deal with additional rainrate fields
         IF myflags.HAVE_GR_RC_RAINRATE EQ 1 THEN pctgoodrcgv[idxexpgt0] = $
            100.0 * FLOAT( gvexp[idxexpgt0]-gvrcrej[idxexpgt0] ) / gvexp[idxexpgt0]
         IF myflags.HAVE_GR_RP_RAINRATE EQ 1 THEN pctgoodrpgv[idxexpgt0] = $
            100.0 * FLOAT( gvexp[idxexpgt0]-gvrprej[idxexpgt0] ) / gvexp[idxexpgt0]
      ENDIF
      IF myflags.HAVE_GR_RR_RAINRATE EQ 1 THEN pctgoodrrgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0]-gvrrrej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_ZDR EQ 1 THEN pctgoodzdrgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_zdr_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_KDP EQ 1 THEN pctgoodkdpgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_kdp_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_RHOHV EQ 1 THEN pctgoodRHOhvgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_RHOhv_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_HID EQ 1 THEN pctgoodhidgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_hid_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_DZERO EQ 1 THEN pctgooddzerogv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_dzero_rej[idxexpgt0] ) / gvexp[idxexpgt0]
      IF myflags.HAVE_GR_NW EQ 1 THEN pctgoodnwgv[idxexpgt0] = $
         100.0 * FLOAT( gvexp[idxexpgt0] - gv_nw_rej[idxexpgt0] ) / gvexp[idxexpgt0]
   ENDELSE
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; restore the subsetted arrays to two dimensions of (PRfootprints, GRsweeps)
gvz = REFORM( gvz, countactual, nswp )
gvzmax = REFORM( gvzmax, countactual, nswp )
gvzstddev = REFORM( gvzstddev, countactual, nswp )
IF nc_file_version GT 1.0 THEN BEGIN
   gvrc = REFORM( gvrc, countactual, nswp )
   gvrcmax = REFORM( gvrcmax, countactual, nswp )
   gvrcstddev = REFORM( gvrcstddev, countactual, nswp )
   gvrp = REFORM( gvrp, countactual, nswp )
   gvrpmax = REFORM( gvrpmax, countactual, nswp )
   gvrpstddev = REFORM( gvrpstddev, countactual, nswp )
ENDIF
gvrr = REFORM( gvrr, countactual, nswp )
gvrrmax = REFORM( gvrrmax, countactual, nswp )
gvrrstddev = REFORM( gvrrstddev, countactual, nswp )
GR_DP_Zdr = REFORM( GR_DP_Zdr, countactual, nswp )
GR_DP_Kdp = REFORM( GR_DP_Kdp, countactual, nswp )
GR_DP_RHOhv = REFORM( GR_DP_RHOhv, countactual, nswp )
GR_DP_Dzero = REFORM( GR_DP_Dzero, countactual, nswp )
GR_DP_Nw = REFORM( GR_DP_Nw, countactual, nswp )
GR_DP_ZdrMax = REFORM( GR_DP_ZdrMax, countactual, nswp )
GR_DP_KdpMax = REFORM( GR_DP_KdpMax, countactual, nswp )
GR_DP_RHOhvMax = REFORM( GR_DP_RHOhvMax, countactual, nswp )
GR_DP_DzeroMax = REFORM( GR_DP_DzeroMax, countactual, nswp )
GR_DP_NwMax = REFORM( GR_DP_NwMax, countactual, nswp )
GR_DP_ZdrStdDev = REFORM( GR_DP_ZdrStdDev, countactual, nswp )
GR_DP_KdpStdDev = REFORM( GR_DP_KdpStdDev, countactual, nswp )
GR_DP_RHOhvStdDev = REFORM( GR_DP_RHOhvStdDev, countactual, nswp )
GR_DP_DzeroStdDev = REFORM( GR_DP_DzeroStdDev, countactual, nswp )
GR_DP_NwStdDev = REFORM( GR_DP_NwStdDev, countactual, nswp )
zraw = REFORM( zraw, countactual, nswp )
zcor = REFORM( zcor, countactual, nswp )
rain3 = REFORM( rain3, countactual, nswp )
DPR_Dm = REFORM( DPR_Dm, countactual, nswp )
DPR_Nw = REFORM( DPR_Nw, countactual, nswp )
top = REFORM( top, countactual, nswp )
botm = REFORM( botm, countactual, nswp )
lat = REFORM( lat, countactual, nswp )
lon = REFORM( lon, countactual, nswp )
dpr_lat = REFORM( dpr_lat, countactual, nswp )
dpr_lon = REFORM( dpr_lon, countactual, nswp )
rnFlag = REFORM( rnFlag, countactual, nswp )
rnType = REFORM( rnType, countactual, nswp )
landOceanFlag = REFORM( landOceanFlag, countactual, nswp )
nearSurfRain = REFORM( nearSurfRain, countactual, nswp )
nearSurfRain_Comb = REFORM( nearSurfRain_Comb, countactual, nswp )
pr_index = REFORM( pr_index, countactual, nswp )
bbStatus = REFORM( bbStatus, countactual, nswp )
clutterStatus = REFORM( clutterStatus, countactual, nswp )
BBHeight = REFORM( BBHeight, countactual, nswp )
IF nc_file_version GT 1.0 THEN BEGIN
   pia = REFORM( pia, countactual, nswp )
   stmTopHgt = REFORM( stmTopHgt, countactual, nswp )
ENDIF
IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   pctgoodpr = REFORM( pctgoodpr, countactual, nswp )
   pctgoodgv =  REFORM( pctgoodgv, countactual, nswp )
   pctgoodrain = REFORM( pctgoodrain, countactual, nswp )
   IF myflags.HAVE_paramDSD EQ 1 THEN BEGIN
      pctgoodDprDm = REFORM( pctgoodDprDm, countactual, nswp )
      pctgoodDprNw = REFORM( pctgoodDprNw, countactual, nswp )
   ENDIF
   IF nc_file_version GT 1.0 THEN BEGIN
     ; deal with additional rainrate fields
      IF myflags.HAVE_GR_RC_RAINRATE EQ 1 THEN pctgoodrcgv = $
         REFORM( pctgoodrcgv, countactual, nswp )
      IF myflags.HAVE_GR_RP_RAINRATE EQ 1 THEN pctgoodrpgv = $
         REFORM( pctgoodrpgv, countactual, nswp )
   ENDIF
   IF myflags.HAVE_GR_RR_RAINRATE EQ 1 THEN pctgoodrrgv = $
      REFORM( pctgoodrrgv, countactual, nswp )
   IF myflags.HAVE_GR_ZDR EQ 1 THEN pctgoodzdrgv = $
      REFORM(pctgoodzdrgv, countactual, nswp )
   IF myflags.HAVE_GR_KDP EQ 1 THEN pctgoodkdpgv = $
      REFORM(pctgoodkdpgv, countactual, nswp )
   IF myflags.HAVE_GR_RHOHV EQ 1 THEN pctgoodRHOhvgv = $
      REFORM(pctgoodRHOhvgv, countactual, nswp )
   IF myflags.HAVE_GR_HID EQ 1 THEN pctgoodhidgv = $
      REFORM(pctgoodhidgv, countactual, nswp )
   IF myflags.HAVE_GR_DZERO EQ 1 THEN pctgooddzerogv = $
      REFORM(pctgooddzerogv, countactual, nswp )
   IF myflags.HAVE_GR_NW EQ 1 THEN pctgoodnwgv = $
      REFORM(pctgoodnwgv, countactual, nswp )
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; For each 'column' of data, find the maximum GR reflectivity value for the
;  footprint, and use this to define a GR match to the DPR-indicated rain type.
;  Using Default GR dBZ thresholds of >=35 for "GV Convective" and <=25 for 
;  "GV Stratiform", or other GR dBZ thresholds provided as user parameters,
;  set DPR rain type to "other" (3) where PR type is Convective and GR isn't, or
;  DPR is Stratiform and GR indicates Convective.  For GR reflectivities between
;  'gvstratiform' and 'gvconvective' thresholds, leave the DPR rain type as-is.

print, ''
max_gvz_per_fp = MAX( gvz, DIMENSION=2)
IF ( gvstratiform GT 0.0 ) THEN BEGIN
   idx2other = WHERE( rnType[*,0] EQ 2 AND max_gvz_per_fp LE gvstratiform, $
                      count2other )
   IF ( count2other GT 0 ) THEN BEGIN  ;rnType[idx2other,*] = 3
      FOR ilev=0, nswp-1 DO BEGIN
         rnType[idx2other,ilev] = 3
      ENDFOR
   ENDIF
   fmtstrng='("No. of footprints switched from Convective to Other = ",I0,",' $
            +' based on Stratiform dBZ threshold = ",F0.1)'
   print, FORMAT=fmtstrng, count2other, gvstratiform
ENDIF ELSE BEGIN
   print, "Leaving PR Convective Rain Type assignments unchanged."
ENDELSE
IF ( gvconvective GT 0.0 ) THEN BEGIN
   idx2other = WHERE( rnType[*,0] EQ 1 AND max_gvz_per_fp GE gvconvective, $
                      count2other )
   IF ( count2other GT 0 ) THEN BEGIN
      FOR ilev=0, nswp-1 DO BEGIN
         rnType[idx2other,ilev] = 3
      ENDFOR
   ENDIF
   fmtstrng='("No. of footprints switched from Stratiform to Other = ",I0,",' $
            +' based on Convective dBZ threshold = ",F0.1)'
   print, FORMAT=fmtstrng, count2other, gvconvective
ENDIF ELSE BEGIN
   print, "Leaving PR Stratiform Rain Type assignments unchanged."
ENDELSE

; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of sample point ranges from the GV radar
; via map projection x,y coordinates computed from lat and lon:

; initialize a gv-centered map projection for the ll<->xy transformations:
sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=site_lat, $
                      center_longitude=site_lon )
XY_km = map_proj_forward( lon, lat, map_structure=smap ) / 1000.
dist = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )
dist = REFORM( dist, countactual, nswp )

; - - - - - - - - - - - - - - - - - - - - - - - -

; build an array of height category for the fixed-height levels, for profiles

hgtcat = rnType   ; for a starter
hgtcat[*] = -99   ; re-initialize to -99
beamhgt = botm    ; for a starter, to build array of center of beam
nhgtcats = N_ELEMENTS(heights)
num_in_hgt_cat = LONARR( nhgtcats )
idxhgtdef = where( botm GT 0.0 AND top GT 0.0, counthgtdef )
IF ( counthgtdef GT 0 ) THEN BEGIN
   IF keyword_set(bb_relative) THEN beamhgt[idxhgtdef] = $
        (top[idxhgtdef]+botm[idxhgtdef])/2 - meanbb + 6.0 $
   ELSE beamhgt[idxhgtdef] = (top[idxhgtdef]+botm[idxhgtdef])/2
   hgtcat[idxhgtdef] = FIX((beamhgt[idxhgtdef]-halfdepth)/(halfdepth*2.0))
  ; deal with points that are too low or too high with respect to the
  ; height layers that have been defined
   idx2low = where( beamhgt[idxhgtdef] LT halfdepth, n2low )
   if n2low GT 0 then hgtcat[idxhgtdef[idx2low]] = -1
   idx2high = where( beamhgt[idxhgtdef] GT (heights[nhgtcats-1]+halfdepth), n2high )
   if n2high GT 0 then hgtcat[idxhgtdef[idx2high]] = -2
ENDIF ELSE BEGIN
   message, "No valid beam heights, quitting case.", /INFO
   status = 1   ; set to FAILED
   goto, errorExit
ENDELSE

;print, (top[idxhgtdef]+botm[idxhgtdef])/2 - meanbb, heights[hgtcat[idxhgtdef]]

; build an array of proximity to the bright band: above=3, within=2, below=1
; -- define above (below) BB as bottom (top) of beam at least 0.750 km above
;    (0.750 kmm below) mean BB height (by default), or "bbwidth" km above/below
;    if BBWIDTH is specified

IF ( N_ELEMENTS(bbwidth) NE 1 ) THEN BEGIN
   bbwidth=0.750
ENDIF ELSE BEGIN
   IF bbwidth GE 100.0 THEN BEGIN
      print, "In fprep_dpr_geo_match_profiles, assuming meters for bbwidth ", $
             "value provided: ", bbwidth, ", converting to km."
      bbwidth = bbwidth/1000.0
   ENDIF
   IF bbwidth GT 2.0 OR bbwidth LT 0.2 THEN BEGIN
      print, "In fprep_dpr_geo_match_profiles, overriding outlier bbwidth value:", $
              bbwidth, " km to 0.750 km"
      bbwidth=0.750
   ENDIF
ENDELSE

bbProx = rnType   ; for a starter
bbProx[*] = 0  ; re-init to Not Defined, leave this way if meanBB is Unknown
countabv = 0   ; init to Not Defined
countblo = 0   ; ditto
countin = 0    ; ditto
IF ( meanBB GT 0.0 ) THEN BEGIN
   num_in_BB_Cat = LONARR(4)
   idxabv = WHERE( botm GT (meanbb+bbwidth), countabv )
   num_in_BB_Cat[3] = countabv
   IF countabv GT 0 THEN bbProx[idxabv] = 3
   idxblo = WHERE( ( top GT 0.0 ) AND ( top LT (meanbb-bbwidth) ), countblo )
   num_in_BB_Cat[1] = countblo
   IF countblo GT 0 THEN bbProx[idxblo] = 1
   idxin = WHERE( (botm LE (meanbb+bbwidth)) AND (top GE (meanbb-bbwidth)), countin )
   num_in_BB_Cat[2] = countin
   IF countin GT 0 THEN bbProx[idxin] = 2
ENDIF
; - - - - - - - - - - - - - - - - - - - - - - - -

; apply the S-to-Ku band adjustment if parameter s2ku is set

IF ( s2ku ) THEN BEGIN
   print, "=================================================================="
   print, "Applying rain/snow adjustments to S-band to match Ku reflectivity."
   print, "=================================================================="
   IF countabv GT 0 THEN BEGIN
     ; grab the above-bb points of the GV reflectivity
      gvz4snow = gvz[idxabv]
     ; find those points with non-missing reflectivity values
      idx2ku = WHERE( gvz4snow GT 0.0, count2ku )
      IF count2ku GT 0 THEN BEGIN
        ; perform the conversion and replace the original values
         gvz[idxabv[idx2ku]] = s_band_to_ku_band( gvz4snow[idx2ku], 'S' )
      ENDIF ELSE print, "No above-BB points for S-to-Ku snow correction"
   ENDIF
   IF countblo GT 0 THEN BEGIN
      gvz4rain = gvz[idxblo]
      idx2ku = WHERE( gvz4rain GT 0.0, count2ku )
      IF count2ku GT 0 THEN BEGIN
         gvz[idxblo[idx2ku]] = s_band_to_ku_band( gvz4rain[idx2ku], 'R' )
      ENDIF ELSE print, "No below-BB points for S-to-Ku rain correction"
   ENDIF
ENDIF

; - - - - - - - - - - - - - - - - - - - - - - - -

; assign pointer variables provided as optional keyword parameters, as provided

IF PTR_VALID(ptr_geometa) THEN *ptr_geometa = mygeometa
IF PTR_VALID(ptr_sweepmeta) THEN *ptr_sweepmeta = mysweeps
IF PTR_VALID(ptr_sitemeta) THEN *ptr_sitemeta = mysite
IF PTR_VALID(ptr_fieldflags) THEN *ptr_fieldflags = myflags
IF PTR_VALID(ptr_filesmeta) THEN *ptr_filesmeta = myfiles
IF PTR_VALID(ptr_gvz) THEN *ptr_gvz = gvz
IF PTR_VALID(ptr_gvzmax) THEN *ptr_gvzmax = gvzmax
IF PTR_VALID(ptr_gvzstddev) THEN *ptr_gvzstddev = gvzstddev
IF nc_file_version GT 1.0 THEN BEGIN
   IF PTR_VALID(ptr_gvrc) THEN *ptr_gvrc = gvrc
   IF PTR_VALID(ptr_gvrcmax) THEN *ptr_gvrcmax = gvrcmax
   IF PTR_VALID(ptr_gvrcstddev) THEN *ptr_gvrcstddev = gvrcstddev
   IF PTR_VALID(ptr_gvrp) THEN *ptr_gvrp = gvrp
   IF PTR_VALID(ptr_gvrpmax) THEN *ptr_gvrpmax = gvrpmax
   IF PTR_VALID(ptr_gvrpstddev) THEN *ptr_gvrpstddev = gvrpstddev
ENDIF
IF PTR_VALID(ptr_gvrr) THEN *ptr_gvrr = gvrr
IF PTR_VALID(ptr_gvrrmax) THEN *ptr_gvrrmax = gvrrmax
IF PTR_VALID(ptr_gvrrstddev) THEN *ptr_gvrrstddev = gvrrstddev
IF PTR_VALID(ptr_GR_DP_Zdr) THEN *ptr_GR_DP_Zdr = GR_DP_Zdr
IF PTR_VALID(ptr_GR_DP_Kdp) THEN *ptr_GR_DP_Kdp = GR_DP_Kdp
IF PTR_VALID(ptr_GR_DP_RHOhv) THEN *ptr_GR_DP_RHOhv = GR_DP_RHOhv
IF PTR_VALID(ptr_GR_DP_Dzero) THEN *ptr_GR_DP_Dzero = GR_DP_Dzero
IF PTR_VALID(ptr_GR_DP_Nw) THEN *ptr_GR_DP_Nw = GR_DP_Nw
IF PTR_VALID(ptr_GR_DP_ZdrMax) THEN *ptr_GR_DP_ZdrMax = GR_DP_ZdrMax
IF PTR_VALID(ptr_GR_DP_KdpMax) THEN *ptr_GR_DP_KdpMax = GR_DP_KdpMax
IF PTR_VALID(ptr_GR_DP_RHOhvMax) THEN *ptr_GR_DP_RHOhvMax = GR_DP_RHOhvMax
IF PTR_VALID(ptr_GR_DP_DzeroMax) THEN *ptr_GR_DP_DzeroMax = GR_DP_DzeroMax
IF PTR_VALID(ptr_GR_DP_NwMax) THEN *ptr_GR_DP_NwMax = GR_DP_NwMax
IF PTR_VALID(ptr_GR_DP_ZdrStdDev) THEN *ptr_GR_DP_ZdrStdDev = GR_DP_ZdrStdDev
IF PTR_VALID(ptr_GR_DP_KdpStdDev) THEN *ptr_GR_DP_KdpStdDev = GR_DP_KdpStdDev
IF PTR_VALID(ptr_GR_DP_RHOhvStdDev) THEN *ptr_GR_DP_RHOhvStdDev = GR_DP_RHOhvStdDev
IF PTR_VALID(ptr_GR_DP_DzeroStdDev) THEN *ptr_GR_DP_DzeroStdDev = GR_DP_DzeroStdDev
IF PTR_VALID(ptr_GR_DP_NwStdDev) THEN *ptr_GR_DP_NwStdDev = GR_DP_NwStdDev
IF PTR_VALID(ptr_GR_DP_HID) THEN *ptr_GR_DP_HID = GR_DP_HIDnew
IF PTR_VALID(ptr_mode_HID) THEN *ptr_mode_HID = mode_HID
IF PTR_VALID(ptr_zraw) THEN *ptr_zraw = zraw
IF PTR_VALID(ptr_zcor) THEN *ptr_zcor = zcor
IF PTR_VALID(ptr_rain3) THEN *ptr_rain3 = rain3
IF PTR_VALID(ptr_dprDm) THEN *ptr_dprDm = DPR_Dm
IF PTR_VALID(ptr_dprNw) THEN *ptr_dprNw = DPR_Nw
IF PTR_VALID(ptr_top) THEN *ptr_top = top
IF PTR_VALID(ptr_botm) THEN *ptr_botm = botm
IF PTR_VALID(ptr_lat) THEN *ptr_lat = lat
IF PTR_VALID(ptr_lon) THEN *ptr_lon = lon
IF PTR_VALID(ptr_dpr_lat) THEN *ptr_dpr_lat = dpr_lat
IF PTR_VALID(ptr_dpr_lon) THEN *ptr_dpr_lon = dpr_lon
IF nc_file_version GT 1.0 THEN BEGIN
   IF PTR_VALID(ptr_pia) THEN *ptr_pia = pia
   IF PTR_VALID(ptr_stmTopHgt) THEN *ptr_stmTopHgt = stmTopHgt
ENDIF
IF PTR_VALID(ptr_nearSurfRain) THEN *ptr_nearSurfRain = nearSurfRain
IF PTR_VALID(ptr_nearSurfRain_Comb) THEN $
    *ptr_nearSurfRain_Comb = nearSurfRain_Comb
IF PTR_VALID(ptr_rnFlag) THEN *ptr_rnFlag = rnFlag
IF PTR_VALID(ptr_rnType) THEN *ptr_rnType = rnType
IF PTR_VALID(ptr_landOcean) THEN *ptr_landOcean = landOceanFlag
IF PTR_VALID(ptr_bbstatus) THEN *ptr_bbstatus = bbStatus
IF PTR_VALID(ptr_clutterStatus) THEN *ptr_clutterStatus=clutterStatus
IF PTR_VALID(ptr_bbHeight) THEN *ptr_bbHeight =bbHeight
IF PTR_VALID(ptr_pr_index) THEN *ptr_pr_index = pr_index
IF PTR_VALID(ptr_bbProx) THEN *ptr_bbProx = bbProx
IF PTR_VALID(ptr_hgtcat) THEN *ptr_hgtcat = hgtcat
IF PTR_VALID(ptr_dist) THEN *ptr_dist = dist
IF PTR_VALID(ptr_xCorner) THEN *ptr_xCorner = xcornew
IF PTR_VALID(ptr_yCorner) THEN *ptr_yCorner = ycornew

IF ( N_ELEMENTS(pctAbvThresh) EQ 1 ) THEN BEGIN
   IF PTR_VALID(ptr_pctgoodpr) THEN *ptr_pctgoodpr = pctgoodpr
   IF PTR_VALID(ptr_pctgoodgv) THEN *ptr_pctgoodgv = pctgoodgv
   IF PTR_VALID(ptr_pctgoodrain) THEN *ptr_pctgoodrain = pctgoodrain
   IF PTR_VALID(ptr_pctgoodDprDm) THEN *ptr_pctgoodDprDm = pctgoodDprDm
   IF PTR_VALID(ptr_pctgoodDprNw) THEN *ptr_pctgoodDprNw = pctgoodDprNw
   IF nc_file_version GT 1.0 THEN BEGIN
      IF PTR_VALID(ptr_pctgoodrcgv) THEN *ptr_pctgoodrcgv = pctgoodrcgv
      IF PTR_VALID(ptr_pctgoodrpgv) THEN *ptr_pctgoodrpgv = pctgoodrpgv
   ENDIF
   IF PTR_VALID(ptr_pctgoodrrgv) THEN *ptr_pctgoodrrgv = pctgoodrrgv
   IF PTR_VALID(ptr_pctgoodzdrgv) THEN *ptr_pctgoodzdrgv = pctgoodzdrgv
   IF PTR_VALID(ptr_pctgoodkdpgv) THEN *ptr_pctgoodkdpgv = pctgoodkdpgv
   IF PTR_VALID(ptr_pctgoodRHOhvgv) THEN *ptr_pctgoodRHOhvgv = pctgoodRHOhvgv
   IF PTR_VALID(ptr_pctgoodhidgv) THEN *ptr_pctgoodhidgv = pctgoodhidgv
   IF PTR_VALID(ptr_pctgooddzerogv) THEN *ptr_pctgooddzerogv = pctgooddzerogv
   IF PTR_VALID(ptr_pctgoodnwgv) THEN *ptr_pctgoodnwgv = pctgoodnwgv
ENDIF

status = 0   ; set to SUCCESS

errorExit:

return, status
END

