; Copyright (C) 2014  NASA/TRMM Satellite Validation Office
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software Foundation, Inc.,
; 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
;**************************************************************************
;+
; rsl_cfradial_to_radar
;
; This function reads a CfRadial file and returns data in a Radar structure.
;
; Syntax:
;     radar = rsl_cfradial_to_radar(cfradial_file [, FIELDS=string_array]
;             [, MAXSWEEPS=integer] [, ERROR=variable] [, /CATCH_ERROR]
;             [, /KEEP_RADAR])
;
; Inputs:
;     cfradial_file: CfRadial file name
;
; Keyword parameters:
;     CATCH_ERROR:
;         Error handler is turned on by default.  Set CATCH_ERROR to 0 to
;         turn off error handler.
;     ERROR:
;         Assign a variable to this keyword to have a boolean error status
;         returned.  A value of 1 (true) means an error occurred,
;         0 means no error.
;     FIELDS:
;         String array containing names of CfRadial data fields to read.
;         Default: all fields.
;     KEEP_RADAR:
;         Set this keyword to return the radar structure if an error
;         occurs.  If an error occurs and this is not set, function returns -1.
;     MAXSWEEPS:
;         Maximum number of sweeps to read.  Default is all sweeps.
;
; Written by:  Bart Kelley, SSAI, April 2014
;-
;***************************************************************************
;

function cfrfields_to_rslfields, cfrfields

; Convert CfRadial field names to RSL field names.
;
; Input argument is a string array or scalar.
;
; Return value:
;    If input is an array, the returned object is an array containing the RSL
;    field names corresponding to the input CfRadial names.  If input is a
;    scalar string, the corresponding name is likewise returned as a scalar
;    string.
;    In the event that no corresponding RSL field name is found for a given
;    CfRadial name, the CfRadial name is returned.

nfields = n_elements(cfrfields)
rslfields = strarr(nfields)

for i = 0, nfields-1 do begin
    thisfield = strupcase(cfrfields[i])
    case thisfield of
        'DBZ':    rslfields[i] = 'DZ'
        'REF':    rslfields[i] = 'DZ'
        'VEL':    rslfields[i] = 'VR'
        'VEL2':   rslfields[i] = 'V2'
        'VEL3':   rslfields[i] = 'V3'
        'WIDTH':  rslfields[i] = 'SW'
        'WIDTH2': rslfields[i] = 'S2'
        'WIDTH3': rslfields[i] = 'S3'
        'ZDR':    rslfields[i] = 'DR'
        'KDP':    rslfields[i] = 'KD'
        'PHIDP':  rslfields[i] = 'PH'
        'PHI':    rslfields[i] = 'PH'
        'RHOHV':  rslfields[i] = 'RH'
        'RHO':    rslfields[i] = 'RH'
        'DBZTOT': rslfields[i] = 'ZT'
        'DBZ_TOT':rslfields[i] = 'ZT'
        'HCLASS': rslfields[i] = 'HC'
        'SQI':    rslfields[i] = 'SQ'
        ; Some variations.
        'REFLECTIVITY': rslfields[i] = 'DZ'
        'VELOCITY': rslfields[i] = 'VR'
        'SPECTRUM_WIDTH': rslfields[i] = 'SW'
        'DIFFERENTIAL_REFLECTIVITY': rslfields[i] = 'DR'
        'DIFFERENTIALREFLECTIVITY':  rslfields[i] = 'DR'
        'DIFFERENTIAL_PHASE': rslfields[i] = 'PH'
        'SPECIFIC_DIFFERENTIAL_PHASE': rslfields[i] = 'KD'
        'HYDROCLASS': rslfields[i] = 'HC'
        else: begin
            rslfields[i] = cfrfields[i]
        end
    endcase
endfor

return, rslfields
end


function rslfield_to_cfrfield, rslfield, count

; Convert RSL field name to CfRadial field name.
; Function returns the corresponding CfRadial field name if found, otherwise
; it returns the null string.
;
; Arguments:
;    rslfield: A two-character RSL field name, for example, 'DZ'.
;    count:    The number of possible matches found is returned through this
;              argument.
;
; Return value:
;    The return value may be a scalar string or a string array.  A string array
;    is returned when there is more than one possible match for a given RSL
;    name.  For example, the RSL field name for reflectivity is 'DZ'.  The
;    corresponding standard name in CfRadial is 'DBZ', but 'REF' is sometimes
;    used.  The return value in this case is the array ['DBZ','REF'].  If a
;    variable is given for the output argument COUNT, it will contain the number
;    of matching names.

thisfield = strupcase(rslfield)
case thisfield of
    'DZ': begin
        count = 2
        return, ['DBZ','REF']
    end
    'VR': begin
        count = 1
        return, 'VEL'
    end
    'SW': begin
        count = 1
        return, 'WIDTH'
    end
    'ZT': begin
        count = 2
        return, ['DBZTOT', 'DBZ_TOT']
    end
    'DR': begin
        count = 1
        return, 'ZDR'
    end
    'KD': begin
        count = 1
        return, 'KDP'
    end
    'PH': begin
        count = 1
        return, 'PHIDP'
    end
    'RH': begin
        count = 1
        return, 'RHOHV'
    end
    'HC': begin
        count = 1
        return, 'HCLASS'
    end
    else: begin
        count = 0
        return, ''
    end
endcase

end


function get_selected_fields, varnames, selfields, nfields

; This function finds CfRadial variables corresponding to the selected fields
; given in "selfields".  It allows field names to be in RSL style (for example,
; VR instead of VEL), and does case-insensitive matching.
;
; Function returns a string array containing the names of the corresponding
; CfRadial variables.
;
; Arguments:
;     varnames:
;         A string array containing the names of all variables in CfRadial file.
;     selfields:
;         A string array of user-selected fields.
;     nfields:
;         Output argument giving the number of selected fields found.
;
; Return value:
;     Function returns a string array of CfRadial variable names corresponding
;     to selected fields.
;

nfields = n_elements(selfields)
cfrfields = strarr(nfields)

j = 0
for i = 0, nfields-1 do begin
    found = 0
    thisfield = selfields[i]
    loc = where(strmatch(varnames,thisfield,/fold),count)
    if count gt 0 then begin
        cfrfields[j] = varnames[loc[0]]
        j++
        found = 1
    endif else begin
        ; If field is two-character RSL style, search for corresponding CfRadial
        ; name.
        if strlen(thisfield) eq 2 then begin
            name = rslfield_to_cfrfield(thisfield,count)
            ; There may be more than one name, e.g., 'DZ'->['DBZ','REF'].
            for k = 0,count-1 do begin
                loc = where(strmatch(varnames,name[k],/fold),count)
                if loc[0] ne -1 then begin
                    cfrfields[j] = varnames[loc[0]]
                    j++
                    found = 1
                endif
            endfor ; k = 0,count-1
        endif
    endelse
    if ~ found then print,'get_selected_fields: Could not find ',$
        'requested field "' + thisfield + '".'
endfor ; i = 0,nfields-1
; Remove any empty elements.
cfrfields = cfrfields[where(cfrfields, count)]
nfields = count
return, cfrfields
end


function get_cfr_rsl_field_list, varnames, fields=fields

; Returns a structure containing an array of CfRadial field variable names,
; an array of corresponding RSL field names, and the number of fields found.
;
; Arguments:
;     varnames:
;        A string array containing the names of all variables in CfRadial file.
;
; Keywords:
;     FIELDS:
;        A string array of field names whose data is to be retrieved from
;        CfRadial.  If omitted, all fields will be retrieved.

; Get field names from array of variable names.

; Get all fields if none were selected.
if n_elements(fields) eq 0 then begin
    ; Search for field variables in the CfRadial short-name convention.  They
    ; begin with uppercase characters.
    nfields = 0
    loc = where(stregex(varnames,'^[A-Z]+',/boolean),count)
    if count gt 0 then begin
        cfrfields = varnames[loc]
        nfields = count
    endif else begin
        ; Check for variations.
        n_longnames = 6 ; The number of names checked below.
        cfrfields = strarr(n_longnames)
        i = 0
        loc = where(strmatch(varnames,'reflectivity',/fold),count)
        if count gt 0 then cfrfields[i++] = varnames[loc]
        loc = where(strmatch(varnames,'velocity',/fold),count)
        if count gt 0 then cfrfields[i++] = varnames[loc]
        loc = where(strmatch(varnames,'spectrum_width',/fold),count)
        if count gt 0 then cfrfields[i++] = varnames[loc]
        loc = where(strmatch(varnames,'differential_reflectivity',/fold),count)
        if count gt 0 then cfrfields[i++] = varnames[loc]
        loc = where(strmatch(varnames,'differential_phase',/fold),count)
        if count gt 0 then cfrfields[i++] = varnames[loc]
        loc = where(strmatch(varnames,'specific_differential_phase',/fold), $
            count)
        if count gt 0 then cfrfields[i++] = varnames[loc]
        if i gt 0 then begin
            cfrfields = cfrfields[0:i-1]
            nfields = i
        endif
    endelse

    if nfields eq 0 then begin
        print,format='(/,"GET_CFR_RSL_FIELD_LIST: Unable to determine ' + $
            'the field variables in this CfRadial.",/,"Use ' + $
            'the FIELDS keyword to specify names of desired variables.",/)'
        return, {cfrfields:'', rslfields:'', nfields:0}
    endif

    rslfields = cfrfields_to_rslfields(cfrfields)
    nfields = n_elements(cfrfields)
endif

; Get selected fields.
if n_elements(fields) gt 0 then begin
    cfrfields = get_selected_fields(varnames, fields, nfields)
    if nfields gt 0 then rslfields = cfrfields_to_rslfields(cfrfields) $
        else rslfields = ''
endif

fieldlist = {cfrfields:cfrfields, rslfields:rslfields, nfields:nfields}
return, fieldlist
end


;******************************;
;     rsl_get_var_attnames     ;
;******************************;

function rsl_get_var_attnames, cfid, varid, count

; Returns a string array containing names of attributes for given netCDF
; variable.  If variable has no attributes, a null string ('') is returned.
;
; Arguments:
;     cfid:   netCDF ID returned by call to NCDF_OPEN.
;     varid:  Name of variable or the variable ID as returned by NCDF_VARDEF.
;
; Keywords:
;     COUNT: Set this to a named variable to return number of attributes.

var = ncdf_varinq(cfid, varid)
attnames = ''
if var.natts ne 0 then begin
    attnames = strarr(var.natts)
    for i = 0, var.natts-1 do begin
        attnames[i] = ncdf_attname(cfid,var.name,i)
    endfor
endif
count = var.natts
return, attnames
end


function rsl_unpack_cfradial_bytes, byteray, scale_factor, add_offset, fillvalue

; This is the algorithm I used to unpack byte data from the sample CfRadial
; file from UCAR.  If fill value is 128, values less than that are unpacked
; differently from values greater than it.  If the fill value is not 128, use
; the conventional method for unpacking.

; Make an array of the same type as scale_factor for unpacked data.
raydata = make_array(n_elements(byteray), type=size(scale_factor,/type))

if fillvalue eq 128 then begin
    s = where(byteray lt 128, count)
    if count gt 0 then raydata[s] = byteray[s]*scale_factor + add_offset
    s = where(byteray gt 128, count)
    if count gt 0 then raydata[s] = (byteray[s]-256.)*scale_factor + add_offset
endif else begin
    ; Fillvalue is not 128, use the conventional method for unpacking.
    s = where(byteray ne fillvalue, count)
    if count gt 0 then raydata[s] = byteray[s]*scale_factor + add_offset
endelse
return, raydata
end


;*******************************;
;       cfr_prt_to_prf          ;
;*******************************;

function cfr_prt_to_prf, cfid, prtvar, timedim

; Convert PRT to PRF.

prf  = fltarr(timedim)
fillvalue = 0.
ncdf_varget, cfid, prtvar, prt
attnames = rsl_get_var_attnames(cfid, prtvar)
loc = where(attnames eq '_FillValue', count)
if count ne 0 then begin
    ncdf_attget,cfid, prtvar, '_FillValue', fillvalue
endif else begin
    loc = where(attnames eq 'missing_value', count)
    if count ne 0 then ncdf_attget,cfid, prtvar, 'missing_value', fillvalue
endelse
; Make sure there's no division by zero for PRF = 1/PRT.
valid = where(prt ne fillvalue and prt ne 0,count)
if count gt 0 then prf[valid] = 1./prt[valid]
return, prf
end


;*******************************;
;        cfr_get_nyquist        ;
;*******************************;

function cfr_get_nyquist, cfid, nyqvar, timedim
nyq_vel = fltarr(timedim)
fillvalue = 0.
ncdf_varget, cfid, nyqvar, nyquist_velocity
attnames = rsl_get_var_attnames(cfid, nyqvar)
loc = where(attnames eq '_FillValue', count)
if count ne 0 then begin
    ncdf_attget,cfid, nyqvar, '_FillValue', fillvalue
endif else begin
    loc = where(attnames eq 'missing_value', count)
    if count ne 0 then ncdf_attget,cfid, nyqvar, 'missing_value', fillvalue
endelse
valid = where(nyquist_velocity ne fillvalue, count)
if count gt 0 then nyq_vel[valid] = nyquist_velocity[valid]
return, nyq_vel
end


;*******************************;
;     rsl_cfradial_to_radar     ;
;*******************************;

function rsl_cfradial_to_radar, cfradfile, fields=fields, maxsweeps=maxsweeps, $
    keep_radar=keep_radar, quiet=quiet, error=error, catch_error=catch_error

noradar = -1
radar = noradar
error = 0
file_opened = 0

if n_elements(catch_error) eq 0 then catch_error = 1
if n_elements(keep_radar) eq 0 then keep_radar = 0
if not keyword_set(quiet) then quiet = 0

; Set up error handler.  If CATCH_ERROR is 0, the error handler is canceled.
catch, errcode
if errcode ne 0 then begin
    catch, /cancel
    print
    print,!error_state.msg_prefix+!error_state.msg
    if !error_state.sys_msg ne '' then print, '  '+!error_state.sys_msg
    message,'Error occurred while processing file '+cfradfile+'.',/informational
    error = 1
    if not keep_radar then radar = -1
    if file_opened then ncdf_close, cfid
    return, radar
endif
if not catch_error then catch, /cancel ; Cancel error handler.

filename = cfradfile
is_tmpfile = 0
if is_compressed(cfradfile) then begin
    filename = rsl_uncompress(cfradfile)
    is_tmpfile = 1
endif
cfid = ncdf_open(filename, /nowrite)
file_opened = 1
info = ncdf_inquire(cfid)

; Get global attributes.
gattnames = strarr(info.ngatts)
for i=0, info.ngatts-1 do begin
    gattnames[i] = ncdf_attname(cfid,i,/global)
endfor

loc = where(gattnames eq 'n_gates_vary',count)
if count gt 0 then begin
    ncdf_attget,cfid,'n_gates_vary',n_gates_vary,/global
    n_gates_vary = strlowcase(n_gates_vary)
endif else n_gates_vary = 'false'

loc = where(gattnames eq 'site_name',count)
if count gt 0 then begin
    ncdf_attget,cfid,'site_name',site_name,/global
    site_name = string(site_name)
endif
; If site_name is empty string, try instrument name.
if site_name eq '' then begin
    loc = where(gattnames eq 'instrument_name',count)
    if count gt 0 then begin
        ncdf_attget,cfid,'instrument_name',instrument_name,/global
        instrument_name = string(instrument_name)
        site_name = instrument_name
    endif
endif

; Get variable names.
varnames = strarr(info.nvars)
for i = 0, info.nvars-1 do begin
    varinfo = ncdf_varinq(cfid,i)
    varnames[i] = varinfo.name
endfor

; Get dimensions.
for i=0,info.ndims-1 do begin
    ncdf_diminq,cfid,i,name,size
    case name of
        'time': timedim = size
        'range': rangedim = size
        'sweep': sweepdim = size
        'n_points': n_points = size
    else:
    endcase
endfor

ncdf_varget,cfid,'sweep_start_ray_index',sweep_start_ray_index
ncdf_varget,cfid,'sweep_end_ray_index',sweep_end_ray_index
maxrays = max(sweep_end_ray_index - sweep_start_ray_index + 1)

; Allocate radar structure

if n_elements(maxsweeps) eq 0 then nsweeps = sweepdim $
    else nsweeps = maxsweeps < nsweeps

fieldlist = get_cfr_rsl_field_list(varnames, fields=fields)
cfrfields = fieldlist.cfrfields
rslfields = fieldlist.rslfields
nfields = fieldlist.nfields
if nfields eq 0 then begin
    print,'RSL_CFRADIAL_TO_RADAR: No fields to process for ' + $
        cfradfile + '.'
    error = 1
    ncdf_close, cfid
    if delete_on_close then spawn, 'rm ' + filename
    return, noradar
endif

radar = rsl_new_radar(nfields, nsweeps, maxrays, rangedim)

ncdf_varget,cfid,'time',time
ncdf_varget,cfid,'azimuth',azimuth
ncdf_varget,cfid,'elevation',elevation

quiet_prev = !quiet
; keep quiet while checking for variables.
!quiet = 1
fixed_angle_fill = -9999.
if ncdf_varid(cfid,'fixed_angle') ne -1 then $
    ncdf_varget,cfid,'fixed_angle',fixed_angle $
    else fixed_angle = fltarr(sweepdim) + fixed_angle_fill
if ncdf_varid(cfid,'sweep_number') ne -1 then $
    ncdf_varget,cfid,'sweep_number',sweep_number $
    else sweep_number = indgen(sweepdim)
if ncdf_varid(cfid,'sweep_mode') ne -1 then begin
    ncdf_varget,cfid,'sweep_mode',sweep_mode
    sweep_mode = string(sweep_mode)
endif else sweep_mode = strarr(sweepdim) + 'azimuth_surveillance'
!quiet = quiet_prev

loc = where(varnames eq 'unambiguous_range', count)
if count gt 0 then begin
    ncdf_varget,cfid,'unambiguous_range',unambiguous_range
    attnames = rsl_get_var_attnames(cfid, 'unambiguous_range')
    loc = where(attnames eq 'units', count)
    if count ne 0 then ncdf_attget,cfid,'unambiguous_range','units',units
    if strcmp(units,'meters') then unambiguous_range = unambiguous_range / 1000.
endif else unambiguous_range = fltarr(timedim) ; Missing, fill with 0's.

loc = where(varnames eq 'pulse_width', count)
if count gt 0 then ncdf_varget,cfid,'pulse_width',pulse_width $
    else pulse_width = fltarr(timedim)
loc = where(varnames eq 'frequency', count)
if count gt 0 then ncdf_varget,cfid,'frequency',frequency $
    else frequency = 0.
; Convert PRT to PRF, checking for additional Doppler cuts (VCP 121).
loc = where(varnames eq 'prt', count)
if count gt 0 then prf  = cfr_prt_to_prf(cfid, 'prt', timedim)
loc = where(varnames eq 'prt2', count)
if count gt 0 then prf2  = cfr_prt_to_prf(cfid, 'prt2', timedim)
loc = where(varnames eq 'prt3', count)
if count gt 0 then prf3  = cfr_prt_to_prf(cfid, 'prt3', timedim)
; Get Nyquist velocity, checking for additional Doppler cuts (VCP 121).
loc = where(varnames eq 'nyquist_velocity', count)
if count gt 0 then nyq_vel = cfr_get_nyquist(cfid,'nyquist_velocity',timedim)
loc = where(varnames eq 'nyquist_velocity2', count)
if count gt 0 then nyq_vel2 = cfr_get_nyquist(cfid,'nyquist_velocity2',timedim)
loc = where(varnames eq 'nyquist_velocity3', count)
if count gt 0 then nyq_vel3 = cfr_get_nyquist(cfid,'nyquist_velocity3',timedim)

if n_gates_vary eq 'true' then begin
    ; Make sure the variables ray_n_gates and ray_start_index exist when
    ; n_gates_vary = 'true'.  I have seen cases where n_gates_vary is
    ; incorrectly set to 'true', where the actual data arrays are 2-D (which
    ; means the number of gates is constant), and ray_n_gates and
    ; ray_start_index were not present.
    loc = where(varnames eq 'ray_n_gates',count1)
    loc = where(varnames eq 'ray_start_index',count2)
    if count1 gt 0 && count2 gt 0 then begin
        ncdf_varget,cfid,'ray_n_gates',ray_n_gates
        ncdf_varget,cfid,'ray_start_index',ray_start_index
    endif else begin
        ; Expected ray location variables were not found. Check the first
        ; field array to see if it is 2-D. If yes, assume n_gates_vary is
        ; set incorrectly and reset it to 'false'.
        fieldvarinfo = ncdf_varinq(cfid,cfrfields[0])
        if fieldvarinfo.ndims eq 2 then begin
            ncdf_diminq,cfid,fieldvarinfo.dim[0],dimname1,dimsize1
            ncdf_diminq,cfid,fieldvarinfo.dim[1],dimname2,dimsize2
            if (dimname1 eq 'time' && dimname2 eq 'range') || $
                (dimname1 eq 'range' && dimname2 eq 'time') then begin
                n_gates_vary = 'false'
            endif
        endif
    endelse
endif

ncdf_varget,cfid,'time_coverage_start',time_coverage_start
time_coverage_start = string(time_coverage_start)
year=0L & month=0L & day=0L & hour=0L & minute=0L & second=0.0
reads, time_coverage_start, year, month, day, hour, minute, second, $
    format='(I4,5(X,I2))'
radar.h.month = month
radar.h.day = day
radar.h.year = year
radar.h.hour = hour
radar.h.minute = minute
radar.h.sec = second

starttime_string = time_coverage_start
; If "time_reference" is present, it supercedes "time_coverage_start" as
; start time used in computing ray times.
loc = where(varnames eq 'time_reference', count)
if count ne 0 then begin
    ncdf_varget,cfid,'time_reference',starttime_string
    starttime_string = string(starttime_string)
endif
reads, starttime_string, year, month, day, hour, minute, second, $
    format='(I4,5(X,I2))'
starttime_julday = julday(month, day, year, hour, minute, second)
sec_to_dayfrac = 1.d/86400.d

if not quiet then print, format='($,"Loading sweep")'

; Put data into radar structure.

for ifield = 0, nfields-1 do begin
    scale_factor = 1.
    add_offset = 0.
    havescale = 0
    havefill = 0
    ; Note: "no_data_flag" in volume header was initialized by rsl_new_volume().
    no_data_flag = radar.volume[ifield].h.no_data_flag
    field_var = cfrfields[ifield]
    varinfo = ncdf_varinq(cfid,field_var)
    datatype = varinfo.datatype

    ; Get variable attributes for scaling and fillvalues.
    attnames = rsl_get_var_attnames(cfid, field_var)
    loc = where(strcmp(attnames,'scale_factor',/fold_case),count)
    if count gt 0 then begin
        ncdf_attget,cfid,field_var,attnames[loc[0]],scale_factor
        havescale = 1
    endif
    loc = where(strcmp(attnames,'add_offset',/fold_case),count)
    if count gt 0 then begin
        ncdf_attget,cfid,field_var,attnames[loc[0]],add_offset
        havescale = 1
    endif
    loc = where(strcmp(attnames,'_FillValue',/fold_case),count)
    if count gt 0 then begin
        ncdf_attget,cfid,field_var,attnames[loc[0]],fillvalue
        havefill = 1
    endif else begin
        ; Check for *missing_value*.
        loc = where(strcmp(attnames,'missing_value',/fold_case),count)
        if count gt 0 then begin
            ncdf_attget,cfid,field_var,attnames[loc[0]],fillvalue 
            havefill = 1
        endif
    endelse

    if n_gates_vary eq 'false' then ncdf_varget,cfid,field_var,field_data

    iswp = 0
    while iswp lt nsweeps do begin
        sttray = sweep_start_ray_index[iswp]
        endray = sweep_end_ray_index[iswp]
        if n_gates_vary eq 'true' then begin
            iray = 0
            for itime = sttray, endray do begin
                ncdf_varget,cfid,field_var,raydata, $
                    offset=ray_start_index[itime],count=ray_n_gates[itime]
                if havefill then filloc = where(raydata eq fillvalue, nfilled)
                if havescale then begin
                    if datatype ne 'BYTE' then $
                        raydata = raydata * scale_factor + add_offset $
                    else raydata = rsl_unpack_cfradial_bytes(raydata, $
                        scale_factor, add_offset, fillvalue)
                endif
                if havefill && nfilled gt 0 then raydata[filloc] = no_data_flag
                radar.volume[ifield].sweep[iswp].ray[iray].range = raydata
                radar.volume[ifield].sweep[iswp].ray[iray].h.ray_num = iray + 1
                iray++
            endfor ; rays
        endif else begin
            lastray=endray-sttray
            raydata = field_data[*,sttray:endray]
            if havefill then filloc = where(raydata eq fillvalue, nfilled)
            if havescale then begin
                if datatype ne 'BYTE' then $
                    raydata = raydata * scale_factor + add_offset $
                else raydata = rsl_unpack_cfradial_bytes(raydata, $
                    scale_factor, add_offset, fillvalue)
            endif
            if havefill && nfilled gt 0 then raydata[filloc] = no_data_flag
            radar.volume[ifield].sweep[iswp].ray[0:lastray].range = raydata
            radar.volume[ifield].sweep[iswp].ray[0:lastray].h.ray_num = $
                indgen(lastray+1) + 1
        endelse
        ; If first field, load ray headers for all fields this sweep.
        if ifield eq 0 then begin
            raytime = time[sttray:endray] * sec_to_dayfrac + starttime_julday
            caldat,raytime,month,day,year,hour,minute,second
            lastray=endray-sttray
            radar.volume.sweep[iswp].ray[0:lastray].h.month = month
            radar.volume.sweep[iswp].ray[0:lastray].h.day = day
            radar.volume.sweep[iswp].ray[0:lastray].h.year = year
            radar.volume.sweep[iswp].ray[0:lastray].h.hour = hour
            radar.volume.sweep[iswp].ray[0:lastray].h.minute = minute
            radar.volume.sweep[iswp].ray[0:lastray].h.sec = second
            radar.volume.sweep[iswp].ray[0:lastray].h.azimuth = $
                azimuth[sttray:endray]
            radar.volume.sweep[iswp].ray[0:lastray].h.elev = $
                elevation[sttray:endray] 
            radar.volume.sweep[iswp].ray[0:lastray].h.elev_num = iswp + 1
            radar.volume.sweep[iswp].ray[0:lastray].h.fix_angle = $
                fixed_angle[iswp]
            if n_elements(prf) ne 0 then $
                radar.volume.sweep[iswp].ray[0:lastray].h.prf = $
                prf[sttray:endray]
            if n_elements(nyq_vel) ne 0 then $
                radar.volume.sweep[iswp].ray[0:lastray].h.nyq_vel = $
                nyq_vel[sttray:endray]
            radar.volume.sweep[iswp].ray[0:lastray].h.pulse_width = $
                pulse_width[sttray:endray]
            radar.volume.sweep[iswp].ray[0:lastray].h.unam_rng = $
                unambiguous_range[sttray:endray]
            if n_elements(ray_n_gates) gt 0 then begin
                radar.volume.sweep[iswp].ray[0:lastray].h.nbins = $
                    ray_n_gates[sttray:endray]
            endif else begin
                radar.volume.sweep[iswp].ray[0:lastray].h.nbins = rangedim
            endelse
            if not quiet then print, format='($,i4)', iswp + 1
        endif
        ; Check for PRF, Nyquist, for additional Doppler cuts (VCP 121).
        if stregex(rslfields[ifield],'[SV]2',/boolean) then begin
            lastray=endray-sttray
            radar.volume[ifield].sweep[iswp].ray[0:lastray].h.prf = $
                prf2[sttray:endray]
            radar.volume[ifield].sweep[iswp].ray[0:lastray].h.nyq_vel = $
                nyq_vel2[sttray:endray]
        endif
        if stregex(rslfields[ifield],'[SV]3',/boolean) then begin
            lastray=endray-sttray
            radar.volume[ifield].sweep[iswp].ray[0:lastray].h.prf = $
                prf3[sttray:endray]
            radar.volume[ifield].sweep[iswp].ray[0:lastray].h.nyq_vel = $
                nyq_vel3[sttray:endray]
        endif
        iswp++
    endwhile  ; sweeps
endfor ; fields

if not quiet then print ; Print newline for sweep report.

loc = where(varnames eq 'radar_beam_width_h', count)
if count gt 0 then ncdf_varget,cfid,'radar_beam_width_h',beam_width_h $
    else beam_width_h = 1.0
loc = where(varnames eq 'radar_beam_width_v', count)
if count gt 0 then ncdf_varget,cfid,'radar_beam_width_v',beam_width_v $
    else beam_width_v = 1.0
radar.volume.sweep.h.beam_width = beam_width_h
radar.volume.sweep.h.horz_half_bw = beam_width_h/2.
radar.volume.sweep.h.vert_half_bw = beam_width_v/2.
radar.volume.sweep.ray.h.beam_width = beam_width_h

; Get gate metadata from *range* attributes.
varinfo = ncdf_varinq(cfid,'range')
for i=0,varinfo.natts-1 do begin
    attname = ncdf_attname(cfid,'range',i)
    if attname eq 'meters_to_center_of_first_gate' then begin
        ncdf_attget,cfid,'range','meters_to_center_of_first_gate',range_bin1
        radar.volume.sweep.ray.h.range_bin1 = range_bin1
    endif
    if attname eq 'meters_between_gates' then begin
        ncdf_attget,cfid,'range','meters_between_gates',gate_size
        radar.volume.sweep.ray.h.gate_size = gate_size
    endif
endfor

ncdf_varget,cfid,'latitude',latitude
ncdf_varget,cfid,'longitude',longitude
loc = where(varnames eq 'altitude',count)
if count gt 0 then ncdf_varget,cfid,'altitude',altitude $
    else altitude = 0.
ncdf_close, cfid
file_opened = 0
if is_tmpfile then spawn, 'rm ' + filename

; Put metadata in headers.

radar.h.radar_name = site_name
radar.h.name = site_name
rsl_latlon_to_radarhdr, radar, latitude, longitude
radar.h.height = altitude
case sweep_mode[0] of
    'azimuth_surveillance': scan_mode = 'PPI'
    'manual_ppi': scan_mode = 'PPI'
    'manual_rhi': scan_mode = 'RHI'
    'elevation_surveillance': scan_mode = 'RHI'
    'rhi': scan_mode = 'RHI'
    else: scan_mode = sweep_mode[0]
endcase
radar.h.scan_mode = scan_mode

radar.volume.h.field_type = rslfields
radar.volume.h.nsweeps = nsweeps
sweep_range = indgen(nsweeps)
for i = 0, nfields-1 do begin
    radar.volume[i].sweep.h.field_type = rslfields[i]
    radar.volume[i].sweep.h.sweep_num = sweep_number[sweep_range] + 1
    radar.volume[i].sweep.h.fixed_angle = fixed_angle[sweep_range]
    if scan_mode ne 'RHI' then radar.volume[i].sweep.h.elev = $
        fixed_angle[sweep_range]
    radar.volume[i].sweep.h.nrays = sweep_end_ray_index[sweep_range] - $
        sweep_start_ray_index [sweep_range] + 1
endfor

; For sweep headers, if CfRadial doesn't contain fixed_angle, get the angle
; from ray at middle of sweep.
if fixed_angle[0] eq fixed_angle_fill then begin
    for i = 0, nsweeps-1 do begin
        medianray = radar.volume[0].sweep[i].h.nrays / 2
        if scan_mode ne 'RHI' then begin
            this_fixed_angle = radar.volume[0].sweep[i].ray[medianray].h.elev
            radar.volume.sweep[i].h.elev = this_fixed_angle 
            radar.volume.sweep[i].h.fixed_angle = this_fixed_angle 
            radar.volume.sweep[i].ray.h.fix_angle = this_fixed_angle
        endif else begin
            this_fixed_angle = radar.volume[0].sweep[i].ray[medianray].h.azimuth
            radar.volume.sweep[i].h.fixed_angle = this_fixed_angle 
            radar.volume.sweep[i].ray.h.fix_angle = this_fixed_angle
        endelse
    endfor
endif

;TODO: If 'V2' exists, make adjustments to previous nrays settings for VCP 121.
; Specifically, set sweep.h.nrays to 0 in sweeps where V[23] and S[23]
; are not in effect:
;   loc = where(stregex(radar.volume.h.field_type,'[SV][23]',/bool),count)
;   if count gt 0 then set radar.volume[loc]sweep.h.nrays to 0 where applicable.

; Beam width for WSR-88D super resolution depends on the number of rays.
; Super-resolution sweeps normally contain 720 rays and have 0.5 degree
; beam width.  Otherwise, beam width is approximately 1 degree.
wsr88d_super_res = radar.volume[0].sweep[0].h.nrays gt 600
if wsr88d_super_res then begin
    for iswp = 0,nsweeps-1 do begin
        if radar.volume[0].sweep[iswp].h.nrays gt 600 then beam_width = 0.5 $
            else beam_width = 1.0
        radar.volume.sweep[iswp].h.beam_width = beam_width
        radar.volume.sweep[iswp].h.horz_half_bw = beam_width/2.
        radar.volume.sweep[iswp].h.vert_half_bw = beam_width/2.
        radar.volume.sweep[iswp].ray.h.beam_width = beam_width
    endfor
endif

if frequency[0] gt 0. then begin
    frequency = frequency[0]
    radar.volume.sweep.ray.h.frequency = frequency / 1.e+9 ; Hz to GHz
    RSL_SPEED_OF_LIGHT = 299792458.0
    radar.volume.sweep.ray.h.wavelength = RSL_SPEED_OF_LIGHT / frequency
endif

return, radar
end
