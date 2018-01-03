pro geo_matchup_mean_z_diffs
;
; DESCRIPTION
; Reads PR and GV reflectivity and spatial fields from a user-selected geo_match
; netCDF file, builds index arrays of categories of range, rain type, bright
; band proximity (above, below, within), and height (13 categories, 1.5-19.5 km
; levels); and an array of actual range.  Computes mean PR-GV reflectivity
; differences for each of the 13 height levels for points within 100 km of the
; ground radar.
;

; "include" file for read_geo_match_netcdf() structs returned
@geo_match_nc_structs.inc

; "include" file for PR data constants
@pr_params.inc

pathpr = '/data/netcdf/geo_match'
ncfilepr = dialog_pickfile(path=pathpr)

while ncfilepr ne '' do begin
   bname = file_basename( ncfilepr )
   prlen = strlen( bname )

; Get uncompressed copy of the found files
cpstatus = uncomp_file( ncfilepr, ncfile1 )
if(cpstatus eq 'OK') then begin
  status = 1   ; init to FAILED
  mygeometa={ geo_match_meta }
  mysweeps={ gv_sweep_meta }
  mysite={ gv_site_meta }
  myflags={ pr_gv_field_flags }
  gvexp=intarr(2)
  gvrej=intarr(2)
  prexp=intarr(2)
  zrawrej=intarr(2)
  zcorrej=intarr(2)
  rainrej=intarr(2)
  gvz=intarr(2)
  zraw=fltarr(2)
  zcor=fltarr(2)
  rain3=fltarr(2)
  top=fltarr(2)
  botm=fltarr(2)
  lat=fltarr(2)
  lon=fltarr(2)
  bb=fltarr(2)
  rnflag=intarr(2)
  rntype=intarr(2)
  pr_index=lonarr(2)

  status = read_geo_match_netcdf( ncfile1, matchupmeta=mygeometa, $
    sweepsmeta=mysweeps, sitemeta=mysite, fieldflags=myflags, $
    gvexpect_int=gvexp, gvreject_int=gvrej, prexpect_int=prexp, $
    zrawreject_int=zrawrej, zcorreject_int=zcorrej, rainreject_int=rainrej, $
    dbzgv=gvz, dbzcor=zcor, dbzraw=zraw, rain3d=rain3, topHeight=top, $
    bottomHeight=botm, latitude=lat, longitude=lon, bbhgt=BB, $
    rainflag_int=rnFlag, raintype_int=rnType, pridx_long=pr_index )

  command3 = "rm -v " + ncfile1
  spawn, command3
endif else begin
  print, 'Cannot copy/unzip netCDF file: ', ncfilepr
  print, cpstatus
  command3 = "rm -v " + ncfile1
  spawn, command3
  goto, errorExit
endelse

site_lat = mysite.site_lat
site_lon = mysite.site_lon
siteID = string(mysite.site_id)
nsweeps = mygeometa.num_sweeps

; get array indices of the non-bogus footprints
idxpractual = where(pr_index GE 0L, countactual)
if (countactual EQ 0) then begin
   print, "No non-bogus data points, quitting case."
   goto, errorExit
endif

; clip the data fields down to the actual footprint points

; Single-level first (don't need BB replicated to all sweeps):
BB = BB[idxpractual]

; Now do the sweep-level arrays - have to build an array index of actual
; points over all the sweep levels
idx3d=long(gvexp)   ; take one of the 2D arrays, make it LONG type
idx3d[*,*] = 0L     ; initialize all points to 0
idx3d[idxpractual,0] = 1L      ; set the first sweep to 1 where non-bogus

; copy the first sweep to the other levels, and make the single-level arrays
; for categorical fields the same dimension as the sweep-level
rnFlagApp = rnFlag
rnTypeApp = rnType
IF ( nsweeps GT 1 ) THEN BEGIN  
   FOR iswp=1, nsweeps-1 DO BEGIN
      idx3d[*,iswp] = idx3d[*,0]
      rnFlag = [rnFlag, rnFlagApp]  ; concatenate another level's worth
      rnType = [rnType, rnTypeApp]
   ENDFOR
ENDIF
; get the indices of all the non-bogus points in the 2D arrays
idxpractual2d = where( idx3d EQ 1L, countactual2d )
if (countactual2d EQ 0) then begin
  ; this shouldn't be able to happen
   print, "No non-bogus 2D data points, quitting case."
   goto, errorExit
endif

; clip the sweep-level arrays
gvexp = gvexp[idxpractual2d]
gvrej = gvrej[idxpractual2d]
prexp = prexp[idxpractual2d]
zrawrej = zrawrej[idxpractual2d]
zcorrej = zcorrej[idxpractual2d]
rainrej = rainrej[idxpractual2d]
gvz = gvz[idxpractual2d]
zraw = zraw[idxpractual2d]
zcor = zcor[idxpractual2d]
rain3 = rain3[idxpractual2d]
top = top[idxpractual2d]
botm = botm[idxpractual2d]
lat = lat[idxpractual2d]
lon = lon[idxpractual2d]
rnFlag = rnFlag[idxpractual2d]
rnType = rnType[idxpractual2d]

; reclassify rain types down to simple categories 1, 2, or 3, where defined
idxrnpos = where(rntype ge 0, countrntype)
if (countrntype GT 0 ) then rntype(idxrnpos) = rntype(idxrnpos)/100

; convert bright band heights from m to km, where defined, and get mean BB hgt
idxbbdef = where(bb GT 0.0, countBB)
if ( countBB GT 0 ) THEN BEGIN
   meanbb_m = FIX(MEAN(bb[idxbbdef]))  ; in meters
   meanbb = meanbb_m/1000.        ; in km
   BB_HgtLo = (meanbb_m-1001)/1500
;  Level above BB is affected if BB_Hgt is 1000m or less below layer center,
;  so BB_HgtHi is highest grid layer considered to be within the BB
   BB_HgtHi = (meanbb_m-500)/1500
   BB_HgtLo = BB_HgtLo < 12
   BB_HgtHi = BB_HgtHi < 12
print, 'Mean BB (km), bblo, bbhi = ', meanbb, BB_HgtLo, BB_HgtHi
ENDIF ELSE BEGIN
   print, "No valid bright band heights, quitting case."
   goto, errorExit
ENDELSE

; build an array of BB proximity: 0 if below, 1 if within, 2 if above
BBprox = gvexp & BBprox[*] = 1
; define below BB as top of beam at least 250m below mean BB height
idxbelowbb = where( top LE (meanbb-250), countbelowbb )
if ( countbelowbb GT 0 ) then BBprox[idxbelowbb] = 0
idxabovebb = where( botm GE (meanbb+250), countabovebb )
if ( countabovebb GT 0 ) then BBprox[idxabovebb] = 2
;idxinbb = where( BBprox EQ 1, countinbb )

; build an array of ranges, range categories from the GV radar

; 1) range via great circle formula:
;phif = !DTOR * lat
;thetaf = !DTOR * lon
;phis = !DTOR * site_lat
;thetas = !DTOR * site_lon
;re = 6371.0   ; radius of earth, km
;term1 = ( sin( (phif-phis)/2 ) )^2
;term2 = cos(phif) * cos(phis) * ( sin((thetaf-thetas)/2) )^2
;dist_by_gc = re * 2 * asin( sqrt( term1+term2 ) )

; 2) range via map projection x,y coordinates:
; initialize a gv-centered map projection for the ll<->xy transformations:
sMap = MAP_PROJ_INIT( 'Azimuthal Equidistant', center_latitude=site_lat, $
                      center_longitude=site_lon )
XY_km = map_proj_forward( lon, lat, map_structure=smap ) / 1000.
dist = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )
;dist_by_xy = SQRT( XY_km[0,*]^2 + XY_km[1,*]^2 )

; array of range categories: 0 for 0<=r<50, 1 for 50<=r<100, 2 for r>=100, etc.
;   (for now we only have points roughly inside 100km, so limit to 2 categs.)
distcat = ( FIX(dist) / 50 ) < 1

; build an array of height category for the traditional VN levels
hgtcat = distcat  ; for a starter
hgtcat[*] = -99   ; re-initialize to -99
beamhgt = botm    ; for a starter, to build array of center of beam
heights = [1.5,3.0,4.5,6.0,7.5,9.0,10.5,12.0,13.5,15.0,16.5,18.0,19.5]
nhgtcats = N_ELEMENTS(heights)
num_in_hgt_cat = LONARR( nhgtcats )
halfdepth = 0.75
idxhgtdef = where( botm GT halfdepth AND top GT halfdepth, counthgtdef )
IF ( counthgtdef GT 0 ) THEN BEGIN
   beamhgt[idxhgtdef] = (top[idxhgtdef]+botm[idxhgtdef])/2
   hgtcat[idxhgtdef] = FIX((beamhgt[idxhgtdef]-halfdepth)/(halfdepth*2.0))
   idx2low = where( beamhgt[idxhgtdef] LT halfdepth, n2low )
   if n2low GT 0 then hgtcat[idxhgtdef[idx2low]] = -1

   FOR i=0, nhgtcats-1 DO BEGIN
      hgtstr =  string(heights[i], FORMAT='(f0.1)')
      idxhgt = where(hgtcat EQ i, counthgts)
      num_in_hgt_cat[i] = counthgts
      if ( counthgts GT 0 ) THEN BEGIN
         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts, " min = ", $
            min(beamhgt[idxhgt]), " max = ", max(beamhgt[idxhgt])
      endif else begin
         print, "HEIGHT = "+hgtstr+" km: npts = ", counthgts
      endelse
   ENDFOR
ENDIF ELSE BEGIN
   print, "No valid beam heights, quitting case."
   goto, errorExit
ENDELSE

bs = 1.
minz4hist = 18.
maxz4hist = 55.
dbzcut = 18.
rangecut = 100.
height = 3.0

device, decomposed = 0
LOADCT, 33

the_struc = { diffsset, $
              meandiff: -99.999, meandist: -99.999, fullcount: 0L,  $
              maxpr: -99.999, maxgv: -99.999, $
              meandiffc: -99.999, countc: 0L, $
              meandiffs: -99.999, counts: 0L, $
              AvgDifByHist: -99.999 $
            }

print, ' Level |  PR-GV    AvgDist   PR MaxZ   GV MaxZ   NumPts '
print, ' -----   -------   -------   -------   -------   ------ '

mnprarr = fltarr(13)
mngvarr = fltarr(13)
levsdata = 0
prz4hist = fltarr(mygeometa.num_footprints)  ; PR dBZ values used for point-to-point mean diffs
gvz4hist = fltarr(mygeometa.num_footprints)  ; GV dBZ values used for point-to-point mean diffs

;# # # # # # # # # # # # # # # # # # # # # # # # #
; Compute a mean dBZ difference at each level

for lev2get = 0, 12 do begin
   IF ( num_in_hgt_cat[lev2get] GT 0 ) THEN BEGIN
      thishgt = (lev2get+1)*1.5
      flag = ''
      prz4hist[*] = 0.0
      gvz4hist[*] = 0.0
      if (lev2get eq BB_HgtLo OR lev2get eq BB_HgtHi) then flag = ' @ BB'
      diffstruc = the_struc
      calc_geo_pr_gv_meandiffs, zcor, gvz, rnType, dist, distcat, hgtcat, $
                             lev2get, dbzcut, rangecut, bs, mnprarr, mngvarr, $
                             havematch, diffstruc,  prz4hist, gvz4hist
      if(havematch eq 1) then begin
         levsdata = levsdata + 1
        ; format level's stats for table output
         stats55 = STRING(diffstruc.meandiff, diffstruc.meandist, $
                       diffstruc.maxpr, diffstruc.maxgv, diffstruc.fullcount, $
                       FORMAT='(" ",4("   ",f7.3),"    ",i4)' )
        ; extract/format level's stats for graphic plots output
         IF ( diffstruc.fullcount GT 0 ) THEN BEGIN
            dbzpr2 = prz4hist[0:diffstruc.fullcount-1]
            dbzgv2 = gvz4hist[0:diffstruc.fullcount-1]
            mndifhstr = string(diffstruc.AvgDifByHist, FORMAT='(f0.3)')
            mndifstr = string(diffstruc.meandiff, diffstruc.fullcount, FORMAT='(f0.3," (",i0,")")')
            mndifstrc = string(diffstruc.meandiffc, diffstruc.countc, FORMAT='(f0.3," (",i0,")")')
            mndifstrs = string(diffstruc.meandiffs, diffstruc.counts, FORMAT='(f0.3," (",i0,")")')
         ENDIF ELSE BEGIN
            print, "No above-threshold points at height " $
                    + string(heights[lev2get], FORMAT='(f0.3)')
         ENDELSE
         prz4hist[*] = 0.0
         gvz4hist[*] = 0.0
      endif
      print, (lev2get+1)*1.5, stats55, flag, FORMAT='(" ",f4.1,a0," ",a0)'
   ENDIF ELSE BEGIN
      print, "No points at height " + string(heights[lev2get], FORMAT='(f0.3)')
   ENDELSE
  ; Plot the PDF graph for preselected level
   if ( thishgt eq height ) then begin
      hgtstr = string(thishgt, FORMAT='(f0.1)')
      hgtline = 'Height = ' + hgtstr + ' km'
      if ( havematch eq 0 ) then begin
         print, ""
         print, "No valid data found for ", hgtline, ", skipping reflectivity histogram.
         Window, xsize=500, ysize=350
         !P.Multi=[0,1,1,0,0]
      endif else begin

       ; Build the PDF plots for 'thishgt' level
         Window, xsize=500, ysize=700
         !P.Multi=[0,1,2,0,0]

         if ( havematch eq 1) then begin
;            prhist = histogram(dbzpr2, min=minz4hist, max=maxz4hist, binsize = bs, $
            prhist = histogram(dbzpr2, min=dbzcut, max=maxz4hist, binsize = bs, $
                               locations = prhiststart)
;            nxhist = histogram(dbzgv2, min=minz4hist, max=maxz4hist, binsize = bs)
            nxhist = histogram(dbzgv2, min=dbzcut, max=maxz4hist, binsize = bs)
            plot, prhiststart, prhist, COLOR = 100, $
                  XTITLE=hgtstr+' km Reflectivity, dBZ', $
                  YTITLE='Number of Gridpoints', $
                  YRANGE=[0,FIX((MAX(prhist)>MAX(nxhist))*1.1)], $
                  TITLE = strmid( bname, 8, prlen-14), CHARSIZE=1
            xyouts, 0.19, 0.95, 'PR', COLOR = 100, /NORMAL, CHARSIZE=1
            plots, [0.14,0.18], [0.955,0.955], COLOR = 100, /NORMAL
            xyouts, 0.6,0.925, hgtline, COLOR = 100, /NORMAL, CHARSIZE=1.5
;            xyouts, 0.6,0.675, tdiffline, COLOR = 100, /NORMAL, CHARSIZE=1
            mndifline = 'PR-'+siteID+' Bias: ' + mndifstr
            mndifhline = 'PR-'+siteID+' Histo Bias: ' + mndifhstr
            mndiflinec = 'PR-'+siteID+' Bias(Conv): ' + mndifstrc
            mndiflines = 'PR-'+siteID+' Bias(Strat): ' + mndifstrs
            oplot, prhiststart, nxhist, COLOR = 200
            xyouts, 0.19, 0.925, siteID, COLOR = 200, /NORMAL, CHARSIZE=1
            plots, [0.14,0.18], [0.93,0.93], COLOR = 200, /NORMAL
            xyouts, 0.6,0.875, mndifline, COLOR = 100, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.85, mndifhline, COLOR = 100, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.825, mndiflinec, COLOR = 100, /NORMAL, CHARSIZE=1
            xyouts, 0.6,0.8, mndiflines, COLOR = 100, /NORMAL, CHARSIZE=1
         endif
         if (flag ne '') then xyouts, 0.6,0.65,'Bright Band Affected', $
                              COLOR = 100, /NORMAL, CHARSIZE=1
      endelse ; if ( havematch eq 1 )
   endif  ; if thishgt eq height
endfor

; Build the mean Z profile plot panel

if (levsdata eq 0) then begin
   print, "No valid data levels found for reflectivity!"
   goto, nextFile
endif

h2plot = (findgen(levsdata) + 1) * 1.5
prmnz2plot = mnprarr[0:levsdata-1]
gvmnz2plot = mngvarr[0:levsdata-1]
plot, prmnz2plot, h2plot, COLOR = 100, XRANGE=[15,40], YRANGE=[0,15], $
      YTICKINTERVAL=1.5, YMINOR=1, $
      XTITLE='Level Mean Reflectivity, dBZ', YTITLE='Height Level, km'
oplot, gvmnz2plot, h2plot, COLOR = 200

xvals = [15,40] & yvals = [height, height]
plots, xvals, yvals, COLOR = 100, LINESTYLE=1
xvalsleg1 = [32,34] & yvalsleg1 = 14
plots, xvalsleg1, yvalsleg1, COLOR = 100, LINESTYLE=1
XYOutS, 34.5, 13.9, 'Stats Height', COLOR = 100, CHARSIZE=1
xvalsbb = [15,40] & yvalsbb = [meanbb, meanbb]
plots, xvalsbb, yvalsbb, COLOR = 100, LINESTYLE=2, THICK=3
yvalsleg2 = 13
plots, xvalsleg1, yvalsleg2, COLOR = 100, LINESTYLE=2, THICK=3
XYOutS, 34.5, 12.9, 'Mean BB Hgt', COLOR = 100, CHARSIZE=1

nextFile:
ncfilepr = dialog_pickfile(path=pathpr)
endwhile

wdelete
errorExit:
end
