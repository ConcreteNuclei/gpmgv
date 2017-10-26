-- Table into which to load the output of stratified_by_dist_stats_to_dbfile.pro

create table dbzdiff_stats_by_dist_pr_v7 (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prmax float,
   gvmax float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);


create table dbzdiff_stats_by_dist_pr_v7_s2ku (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prmax float,
   gvmax float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);


create table dbzdiff_stats_by_dist_pr_v7_bbrel (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prmax float,
   gvmax float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);


create table dbzdiff_stats_by_dist_pr_v7_s2ku_bbrel (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prmax float,
   gvmax float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);

select percent_of_bins, rangecat, gvtype, radar_id, orbit, height, sum(numpts) as totalany into temp anytotal from dbzdiff_stats_by_dist_pr_v7 where regime='Total' group by 1,2,3,4,5,6;

select percent_of_bins, rangecat, gvtype, radar_id, orbit, height, sum(numpts) as totaltypes into temp totalbytypes from dbzdiff_stats_by_dist_pr_v7 where regime!='Total' group by 1,2,3,4,5,6;

select a.*, b.totaltypes from anytotal a, totalbytypes b where a.percent_of_bins = b.percent_of_bins and a.rangecat = b.rangecat and a.gvtype = b.gvtype and a.radar_id = b.radar_id and a.orbit = b.orbit and a.height = b.height and a.totalany < b.totaltypes;

delete from dbzdiff_stats_by_dist_pr_v7;
\copy dbzdiff_stats_by_dist_pr_v7 from '/data/tmp/StatsByDist_DPR_GR_Pct70_DefaultS.unl' with delimiter '|' 


delete from dbzdiff_stats_by_dist_pr_v7_s2ku;
\copy dbzdiff_stats_by_dist_pr_v7_s2ku from '/tmp/StatsByDist_PR_GR_Pct70_allYrs_S2Ku.unl' with delimiter '|' 


delete from dbzdiff_stats_by_dist_pr_v7_bbrel;
\copy dbzdiff_stats_by_dist_pr_v7_bbrel from '/data/tmp/StatsByDist_DPR_GR_Pct70_BBrel_DefaultS.unl' with delimiter '|' 
delete from dbzdiff_stats_by_dist_pr_v7_s2ku_bbrel;
\copy dbzdiff_stats_by_dist_pr_v7_s2ku_bbrel from '/data/tmp/StatsByDist_DPR_GR_Pct70_BBrel_S2Ku.unl' with delimiter '|' 

-- table with PR and GR sample Standard Deviations in place of Max values
create table dbzdiff_stats_by_dist_pr_s2ku_bbrel_sd (
   percent_of_bins int,
   rangecat int,
   gvtype char(4),
   regime character varying(10),
   radar_id character varying(15),
   orbit integer,
   height float,
   meandiff float,
   diffstddev float,
   prstddev float,
   gvstddev float,
   prmean float,
   gvmean float,
   gvbinmax float,
   gvbinstddev float,
   numpts int,
   primary key (percent_of_bins, rangecat, gvtype, regime, radar_id, orbit, height)
);
delete from dbzdiff_stats_by_dist_pr_s2ku_bbrel_sd;
\copy dbzdiff_stats_by_dist_pr_s2ku_bbrel_sd from '/data/tmp/StatsByDist_DPR_GR_Pct70_StdDevMode_BBrel_S2Ku.unl' with delimiter '|' 

-- "Best" bias regime (stratiform above BB), broken out by site and range:
select radar_id, rangecat*50+25 as meanrangekm, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_pr_v7 where regime='S_above' and numpts>5 and percent_of_bins=95 group by 1,2 order by 1,2;

-- "Best" bias regime (stratiform above BB), broken out by site only:
select radar_id, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_pr_v7 where regime='S_above' and numpts>5 group by 1 order by 1;

-- As above, but output to HTML table
\o /data/tmp/BiasByDistance.html \\select radar_id, rangecat*50+25 as mean_range_km, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as mean_diff_dbz, sum(numpts) as total from dbzdiff_stats_by_dist_pr_v7 where regime='S_above' and numpts>5 and percent_of_bins=95 group by 1,2 order by 1,2;

-- Bias by site, height, and regime(s), for given gv source
select radar_id, height, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiffavg, sum(numpts) as total from dbzdiff_stats_by_dist_pr_v7 where regime like 'S_%' and numpts>0 and gvtype='GeoM' group by 1,2 order by 1,2;


-- "Best" bias regime (stratiform above BB), broken out by site, GV type and range:
select gvtype, radar_id, rangecat*50+25 as meanrangekm, round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, round((sum(prmean*numpts)/sum(numpts))*100)/100 as meanpr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as meangv, sum(numpts) as total from dbzdiff_stats_by_dist_pr_v7 where regime='S_above' and numpts>5 group by 1,2,3 order by 1,2,3;

-- Non-site/regime-specific summary stats, broken out by GV type, height and range only
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(numpts) as n, gvtype, height, rangecat
 into temp dbzsums from dbzdiff_stats_by_dist_pr_v7 where meandiff > -99.9
 group by 4,5,6 order by 4,5,6; 
select round(100.*w/n)/100. as bias, gvtype, height, rangecat from dbzsums; 

-- Full breakout: site, regime, raintype, height and range
select sum(meandiff*numpts) as w, sum(diffstddev*numpts) as s,
       sum(prmean*numpts) as p, sum(gvmean*numpts) as g,
       max(prmax) as px, max(gvmax) as gx,
       sum(numpts) as n, gvtype, regime, radar_id, height, rangecat
  into temp sitedbzsums from dbzdiff_stats_by_dist
 where meandiff > -99.9 and diffstddev > -99.9
 group by 8,9,10,11,12 order by 8,9,10,11,12;

select a.radar_id, a.regime, a.height, a.rangecat, round(100*(a.w/a.n))/100 as bias_vs_2A55, round(100*(a.s/a.n))/100 as stddev2A55, a.n as num_2A55,  round(100*(b.w/b.n))/100 as bias_vs_REORD, round(100*(b.s/b.n))/100 as stddevREORD, b.n as num_REORD from sitedbzsums a, sitedbzsums b where a.gvtype = '2A55' and b.gvtype = 'REOR' and a.radar_id = b.radar_id and a.regime = b.regime and a.height = b.height and a.rangecat = b.rangecat order by 1,2,4,3;

select a.radar_id, a.regime, a.height, a.rangecat, round(100*(a.w/a.n))/100 as bias_vs_2A55, round(100*(b.w/b.n))/100 as bias_vs_GEOM, round(100*(a.s/a.n))/100 as stddev2A55, round(100*(b.s/b.n))/100 as stddevGEOM, a.n as num_2A55, b.n as num_GEOM from sitedbzsums a, sitedbzsums b where a.gvtype = '2A55' and b.gvtype = 'GeoM' and a.radar_id = b.radar_id and a.regime = b.regime and a.height = b.height and a.rangecat = b.rangecat and a.regime = 'S_above' order by 1,2,4,3; 

select a.radar_id, a.regime, a.height, a.rangecat, round(100*(a.w/a.n))/100 as bias_vs_REOR, round(100*(b.w/b.n))/100 as bias_vs_GEOM, round(100*(a.s/a.n))/100 as stddevREOR, round(100*(b.s/b.n))/100 as stddevGEOM, a.n as num_REOR, b.n as num_GEOM from sitedbzsums a, sitedbzsums b where a.gvtype = 'REOR' and b.gvtype = 'GeoM' and a.radar_id = b.radar_id and a.regime = b.regime and a.height = b.height and a.rangecat = b.rangecat and a.regime = 'S_above' order by 1,2,4,3; 

select a.radar_id, a.regime, round(100*SUM(a.w)/SUM(a.n))/100 as bias_vs_GRID, round(100*SUM(b.w)/SUM(b.n))/100 as bias_vs_GEOM, round(100*SUM(a.s)/SUM(a.n))/100 as stddevGRID, round(100*SUM(b.s)/SUM(b.n))/100 as stddevGEOM, SUM(a.n) as num_GRID, SUM(b.n) as num_GEOM from sitedbzsums a, sitedbzsums b where a.gvtype = 'REOR' and b.gvtype = 'GeoM' and a.radar_id = b.radar_id and a.regime = b.regime and a.height = b.height and a.rangecat = b.rangecat and a.regime = 'S_above' group by 1,2 order by 1,2;

-- "Best" bias regime (stratiform above BB), broken out by site and month, for 2A55:
select a.radar_id, date_trunc('month',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_pr_v7 a, overpass_event b where regime='S_above' and numpts>5 and percent_of_bins=95 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id ='KAMX' group by 1,2 order by 1,2;

-- Vertical profiles of PR and GV mean Z:
select radar_id, height, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from dbzdiff_stats_by_dist_pr_v7 where rangecat<2 and gvtype='REOR' group by 1,2 order by 1,2;

select gvtype, radar_id, height, round((sum(prmean*numpts)/sum(numpts))*100)/100 as pr, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as gv, sum(numpts) as n from dbzdiff_stats_by_dist_pr_v7 where rangecat<2 group by 1,2,3 order by 2,1,3;


-- C, S, and Any AGL-based profiles for input to plot_mean_profiles.pro
  select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, round((sum(a.prstddev*a.numpts)/sum(a.numpts))*100)/100 as prsdc, round((sum(a.gvstddev*a.numpts)/sum(a.numpts))*100)/100 as gvsdc, sum(a.numpts) as nc into temp tempc from dbzdiff_stats_by_dist_pr_v7 a where regime like ('C_%') and numpts>4 group by 1 order by 1;
  select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, round((sum(b.prstddev*b.numpts)/sum(b.numpts))*100)/100 as prsds, round((sum(b.gvstddev*b.numpts)/sum(b.numpts))*100)/100 as gvsds, sum(b.numpts) as ns into temp temps from dbzdiff_stats_by_dist_pr_v7 b where regime like ('S_%') and numpts>4 group by 1 order by 1;
  select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, round((sum(c.prstddev*c.numpts)/sum(c.numpts))*100)/100 as prsd, round((sum(c.gvstddev*c.numpts)/sum(c.numpts))*100)/100 as gvsd, sum(c.numpts) as n into temp tempt from dbzdiff_stats_by_dist_pr_v7 c where regime ='Total' and numpts>4 group by 1 order by 1;
  select a.height, prc, gvc, prsdc, gvsdc, nc, prs, gvs, prsds, gvsds, ns, pr, gv, prsd, gvsd, n from tempt a left outer join temps b on a.height=b.height left outer join tempc c on a.height=c.height order by 1;
  drop table tempc;
  drop table temps;
  drop table tempt;

-- as above but S2Ku GR Z
  select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, round((sum(a.prstddev*a.numpts)/sum(a.numpts))*100)/100 as prsdc, round((sum(a.gvstddev*a.numpts)/sum(a.numpts))*100)/100 as gvsdc, sum(a.numpts) as nc into temp tempc from dbzdiff_stats_by_dist_pr_v7_s2ku a where regime like ('C_%') and numpts>4 group by 1 order by 1;
  select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, round((sum(b.prstddev*b.numpts)/sum(b.numpts))*100)/100 as prsds, round((sum(b.gvstddev*b.numpts)/sum(b.numpts))*100)/100 as gvsds, sum(b.numpts) as ns into temp temps from dbzdiff_stats_by_dist_pr_v7_s2ku b where regime like ('S_%') and numpts>4 group by 1 order by 1;
  select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, round((sum(c.prstddev*c.numpts)/sum(c.numpts))*100)/100 as prsd, round((sum(c.gvstddev*c.numpts)/sum(c.numpts))*100)/100 as gvsd, sum(c.numpts) as n into temp tempt from dbzdiff_stats_by_dist_pr_v7_s2ku c where regime ='Total' and numpts>4 group by 1 order by 1;
  select a.height, prc, gvc, prsdc, gvsdc, nc, prs, gvs, prsds, gvsds, ns, pr, gv, prsd, gvsd, n from tempt a left outer join temps b on a.height=b.height left outer join tempc c on a.height=c.height order by 1;
  drop table tempc;
  drop table temps;
  drop table tempt;


-- C, S, and Any  **BB-RELATIVE** profiles for input to plot_mean_profiles.pro
  select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, round((sum(a.prstddev*a.numpts)/sum(a.numpts))*100)/100 as prsdc, round((sum(a.gvstddev*a.numpts)/sum(a.numpts))*100)/100 as gvsdc, sum(a.numpts) as nc into temp tempc from dbzdiff_stats_by_dist_pr_v7_bbrel a where regime like ('C_%') and numpts>4 group by 1 order by 1;
  select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, round((sum(b.prstddev*b.numpts)/sum(b.numpts))*100)/100 as prsds, round((sum(b.gvstddev*b.numpts)/sum(b.numpts))*100)/100 as gvsds, sum(b.numpts) as ns into temp temps from dbzdiff_stats_by_dist_pr_v7_bbrel b where regime like ('S_%') and numpts>4 group by 1 order by 1;
  select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, round((sum(c.prstddev*c.numpts)/sum(c.numpts))*100)/100 as prsd, round((sum(c.gvstddev*c.numpts)/sum(c.numpts))*100)/100 as gvsd, sum(c.numpts) as n into temp tempt from dbzdiff_stats_by_dist_pr_v7_bbrel c where regime ='Total' and numpts>4 group by 1 order by 1;
  select a.height, prc, gvc, prsdc, gvsdc, nc, prs, gvs, prsds, gvsds, ns, pr, gv, prsd, gvsd, n from tempt a left outer join temps b on a.height=b.height left outer join tempc c on a.height=c.height order by 1;
  drop table tempc;
  drop table temps;
  drop table tempt;

-- as above but S2Ku GR Z
  select a.height, round((sum(a.prmean*a.numpts)/sum(a.numpts))*100)/100 as prc, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as gvc, round((sum(a.prstddev*a.numpts)/sum(a.numpts))*100)/100 as prsdc, round((sum(a.gvstddev*a.numpts)/sum(a.numpts))*100)/100 as gvsdc, sum(a.numpts) as nc into temp tempc from dbzdiff_stats_by_dist_pr_s2ku_bbrel_sd a where regime like ('C_%') and numpts>4 group by 1 order by 1;
  select b.height, round((sum(b.prmean*b.numpts)/sum(b.numpts))*100)/100 as prs, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as gvs, round((sum(b.prstddev*b.numpts)/sum(b.numpts))*100)/100 as prsds, round((sum(b.gvstddev*b.numpts)/sum(b.numpts))*100)/100 as gvsds, sum(b.numpts) as ns into temp temps from dbzdiff_stats_by_dist_pr_s2ku_bbrel_sd b where regime like ('S_%') and numpts>4 group by 1 order by 1;
  select c.height, round((sum(c.prmean*c.numpts)/sum(c.numpts))*100)/100 as pr, round((sum(c.gvmean*c.numpts)/sum(c.numpts))*100)/100 as gv, round((sum(c.prstddev*c.numpts)/sum(c.numpts))*100)/100 as prsd, round((sum(c.gvstddev*c.numpts)/sum(c.numpts))*100)/100 as gvsd, sum(c.numpts) as n into temp tempt from dbzdiff_stats_by_dist_pr_s2ku_bbrel_sd c where regime ='Total' and numpts>4 group by 1 order by 1;
  select a.height, prc, gvc, prsdc, gvsdc, nc, prs, gvs, prsds, gvsds, ns, pr, gv, prsd, gvsd, n from tempt a left outer join temps b on a.height=b.height left outer join tempc c on a.height=c.height order by 1;
  drop table tempc;
  drop table temps;
  drop table tempt;

-- Case-by-case differences for GeoM
select radar_id, orbit,round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total into temp statsgeo from dbzdiff_stats_by_dist_pr_v7 where regime='S_above' and numpts>5 and gvtype='GeoM' and rangecat<2 group by 1,2 order by 1,2;

-- Case-by-case differences from the site's long term mean difference over all cases
select a.radar_id, b.orbit, a.meanmeandiff-meangeo as diffgeo, a.total as numgeo into temp statsfromltmean from statsgeo a, stats2a55 b, statsreo c, statsmeanall d where a.radar_id = b.radar_id and b.radar_id = c.radar_id and c.radar_id=d.radar_id and a.orbit=b.orbit and b.orbit=c.orbit;

-- Number of cases whose deviation from the long-term difference exceeds 1 dbz, by source
select radar_id, count(*) as ngeo into temp geo_off from statsfromltmean where abs(diffgeo) > 1  group by 1 order by 1;
select radar_id, count(*) as nreo into temp reo_off from statsfromltmean where abs(diffreo) > 1  group by 1 order by 1;
select radar_id, count(*) as n55 into temp a55_off from statsfromltmean where abs(diff55) > 1  group by 1 order by 1;
select a.radar_id, ngeo, n55, nreo from geo_off a, a55_off b, reo_off c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
select * from geo_off a full outer join a55_off using (radar_id) full outer join reo_off using (radar_id);
-- As above, but for "significant coverage" geomatch cases:
select radar_id, count(*) as ngeo into temp geo_off30 from statsfromltmean where abs(diffgeo) > 1 and numgeo>30 group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo from geo_off30 a, a55_off b, reo_off c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
select * from geo_off30 a full outer join a55_off using (radar_id) full outer join reo_off using (radar_id);

-- Number of cases whose deviation from the long-term difference exceeds 2 dbz, by source
select radar_id, count(*) as ngeo into temp geo_offby2 from statsfromltmean where abs(diffgeo) > 2  group by 1 order by 1;
select radar_id, count(*) as nreo into temp reo_offby2 from statsfromltmean where abs(diffreo) > 2  group by 1 order by 1;
select radar_id, count(*) as n55 into temp a55_offby2 from statsfromltmean where abs(diff55) > 2  group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo from geo_offby2 a, a55_offby2 b, reo_offby2 c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
select * from geo_offby2 a full outer join a55_offby2 using (radar_id) full outer join reo_offby2 using (radar_id);
-- As above, but for "significant coverage" geomatch cases:
select radar_id, count(*) as ngeo into temp geo_off30by2 from statsfromltmean where abs(diffgeo) > 2 and numgeo>30 group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo from geo_off30by2 a, a55_offby2 b, reo_offby2 c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
select * from geo_off30by2 a full outer join a55_offby2 using (radar_id) full outer join reo_offby2 using (radar_id);

-- Number of cases whose deviation from the long-term difference exceeds 3 dbz, by source
select radar_id, count(*) as ngeo into temp geo_offby3 from statsfromltmean where abs(diffgeo) > 3  group by 1 order by 1;
select radar_id, count(*) as nreo into temp reo_offby3 from statsfromltmean where abs(diffreo) > 3  group by 1 order by 1;
select radar_id, count(*) as n55 into temp a55_offby3 from statsfromltmean where abs(diff55) > 3  group by 1 order by 1;
select a.radar_id, ngeo, n55, nreo from geo_offby3 a, a55_offby3 b, reo_offby3 c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
-- As above, but for "significant coverage" geomatch cases:
select radar_id, count(*) as ngeo into temp geo_off30by3 from statsfromltmean where abs(diffgeo) > 3 and numgeo>30 group by 1 order by 1;
--select a.radar_id, ngeo, n55, nreo from geo_off30by3 a, a55_offby3 b, reo_offby3 c where a.radar_id=b.radar_id and b.radar_id = c.radar_id order by 1;
select * from geo_off30by3 a full outer join a55_offby3 using (radar_id) full outer join reo_offby3 using (radar_id);

-- INPUT FOR PLOT_EVENT_SERIES.PRO
\t \a \f '|' \o /tmp/event_best_diffs_PR_70pts5_s2ku.txt \\select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meanmeandiff, sum(numpts) as total from dbzdiff_stats_by_dist_pr_v7_s2ku a, overpass_event b where regime='S_above' and numpts>4 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id not in ('RGSN','DARW') and b.sat_id='PR' and percent_of_bins=70 group by 1,2 order by 1,2;

select a.radar_id, date_trunc('day',b.overpass_time at time zone 'UTC'), round((sum(meandiff*numpts)/sum(numpts))*100)/100 as meandiff, round((sum(gvmean*numpts)/sum(numpts))*100)/100 as mean_gv_dbz, round((max(gvmax)*100)/100) as gvmax, round((max(prmax)*100)/100) as prmax, sum(numpts) as total from dbzdiff_stats_by_dist_pr_v7 a, overpass_event b where regime='S_above' and numpts>25 and a.orbit=b.orbit and a.radar_id=b.radar_id and a.radar_id not in ('RGSN','DARW') group by 1,2 order by 1,2;
