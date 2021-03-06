-- All regimes broken out by site and regime, V6 orig vs Ku, 2008:
drop table commontemp;

select  a.rangecat, a.regime, a.radar_id, a.orbit, a.height into temp commontemp from dbzdiff_stats_by_dist_geo_V6BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b where a.rangecat<2 and a.radar_id < 'KWAJ' and a.numpts>4 and b.numpts>4 and a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.regime not in ('Total') and a.orbit between 57713 and 63364;

select a.radar_id, a.regime, round((sum(a.meandiff*a.numpts)/sum(a.numpts))*100)/100 as v6meandiff, round((sum(a.gvmean*a.numpts)/sum(a.numpts))*100)/100 as v6grmean, sum(a.numpts) as n_v6, round((sum(b.meandiff*b.numpts)/sum(b.numpts))*100)/100 as v6meandiffku, round((sum(b.gvmean*b.numpts)/sum(b.numpts))*100)/100 as v6grmeanku, sum(b.numpts) as n_v6ku from dbzdiff_stats_by_dist_geo_V6BBrel a, dbzdiff_stats_by_dist_geo_s2ku_V6BBrel b, commontemp c where  a.height=b.height and a.orbit=b.orbit and a.radar_id=b.radar_id and a.rangecat = b.rangecat and a.regime = b.regime and a.height=c.height and a.orbit=c.orbit and a.radar_id=c.radar_id and a.rangecat = c.rangecat and a.regime = c.regime group by 1,2 order by 2,1;

 radar_id | regime  | v6meandiff | v6grmean | n_v6  | v6meandiffku | v6grmeanku | n_v6ku 
----------+---------+------------+----------+-------+--------------+------------+--------
 KAMX     | C_above |      -1.55 |    32.43 |   451 |        -0.13 |         31 |    451
 KBMX     | C_above |      -2.47 |     36.3 |  2464 |        -0.52 |      34.35 |   2464
 KBRO     | C_above |      -2.89 |    36.23 |   437 |        -0.92 |      34.25 |    437
 KBYX     | C_above |       -0.4 |    32.63 |   107 |         1.04 |      31.18 |    107
 KCLX     | C_above |      -1.43 |    29.96 |  1114 |        -0.28 |       28.8 |   1114
 KCRP     | C_above |       2.37 |    28.75 |    17 |         3.38 |      27.74 |     17
 KDGX     | C_above |      -1.74 |    31.81 |   927 |        -0.37 |      30.44 |    927
 KEVX     | C_above |      -0.72 |    31.73 |  1237 |         0.63 |      30.38 |   1237
 KFWS     | C_above |      -1.26 |       33 |  1074 |         0.25 |      31.49 |   1074
 KGRK     | C_above |      -1.06 |    35.36 |   564 |         0.77 |      33.53 |    564
 KHGX     | C_above |      -0.38 |    31.73 |   648 |         0.97 |      30.37 |    648
 KHTX     | C_above |      -1.26 |    33.44 |  2268 |         0.33 |      31.86 |   2268
 KJAX     | C_above |      -2.62 |    32.35 |  1253 |        -1.18 |      30.92 |   1253
 KJGX     | C_above |      -1.39 |    32.82 |   997 |         0.15 |      31.28 |    997
 KLCH     | C_above |       -2.1 |    32.05 |  1052 |         -0.7 |      30.65 |   1052
 KLIX     | C_above |      -1.76 |    33.44 |  1032 |        -0.17 |      31.86 |   1032
 KMLB     | C_above |        0.2 |    31.35 |   485 |         1.51 |      30.04 |    485
 KMOB     | C_above |        2.4 |    29.05 |   765 |         3.49 |      27.95 |    765
 KSHV     | C_above |      -1.98 |    33.43 |  2031 |        -0.43 |      31.88 |   2031
 KTBW     | C_above |      -0.91 |    31.94 |   602 |         0.46 |      30.57 |    602
 KTLH     | C_above |      -2.02 |    30.89 |   480 |        -0.76 |      29.62 |    480
 KAMX     | C_below |      -1.77 |     41.7 |   873 |        -3.59 |      43.52 |    873
 KBMX     | C_below |      -1.04 |    42.46 |   538 |        -2.93 |      44.35 |    538
 KBRO     | C_below |      -2.61 |    42.13 |   167 |        -4.47 |      43.99 |    167
 KBYX     | C_below |      -1.25 |    41.24 |   568 |        -3.04 |      43.02 |    568
 KCLX     | C_below |      -0.09 |     40.3 |   510 |        -1.79 |         42 |    510
 KCRP     | C_below |         -2 |    41.18 |   260 |        -3.78 |      42.96 |    260
 KDGX     | C_below |      -1.26 |       41 |   932 |        -3.02 |      42.76 |    932
 KEVX     | C_below |       0.59 |    41.17 |  1051 |        -1.18 |      42.95 |   1051
 KFWS     | C_below |       0.55 |     40.7 |   407 |        -1.19 |      42.44 |    407
 KGRK     | C_below |       1.24 |     39.6 |   189 |         -0.4 |      41.24 |    189
 KHGX     | C_below |       0.47 |    40.14 |   516 |        -1.22 |      41.82 |    516
 KHTX     | C_below |      -0.46 |    41.47 |   496 |        -2.27 |      43.28 |    496
 KJAX     | C_below |       0.01 |    40.74 |   852 |        -1.73 |      42.48 |    852
 KJGX     | C_below |       0.18 |    40.86 |   446 |        -1.57 |      42.61 |    446
 KLCH     | C_below |       -1.4 |     42.1 |   410 |        -3.25 |      43.96 |    410
 KLIX     | C_below |      -1.37 |    43.89 |   833 |        -3.38 |       45.9 |    833
 KMLB     | C_below |       1.77 |    39.59 |   610 |         0.13 |      41.23 |    610
 KMOB     | C_below |      -0.71 |    40.78 |   665 |        -2.45 |      42.52 |    665
 KSHV     | C_below |      -1.15 |    44.26 |   464 |         -3.2 |       46.3 |    464
 KTBW     | C_below |      -0.91 |     42.2 |   663 |        -2.77 |      44.07 |    663
 KTLH     | C_below |      -1.46 |    41.03 |   395 |        -3.23 |       42.8 |    395
 KAMX     | C_in    |      -1.94 |    39.89 |  1459 |        -1.94 |      39.89 |   1459
 KBMX     | C_in    |      -1.99 |    41.38 |  3918 |        -1.99 |      41.38 |   3918
 KBRO     | C_in    |      -2.82 |    41.18 |   516 |        -2.82 |      41.18 |    516
 KBYX     | C_in    |      -1.35 |    38.85 |   653 |        -1.35 |      38.85 |    653
 KCLX     | C_in    |      -1.72 |    39.62 |  2259 |        -1.72 |      39.62 |   2259
 KCRP     | C_in    |      -0.82 |    37.36 |   287 |        -0.82 |      37.36 |    287
 KDGX     | C_in    |      -1.68 |    39.74 |  2448 |        -1.68 |      39.74 |   2448
 KEVX     | C_in    |      -0.21 |    39.38 |  3452 |        -0.21 |      39.38 |   3452
 KFWS     | C_in    |      -0.54 |    38.86 |  1674 |        -0.54 |      38.86 |   1674
 KGRK     | C_in    |      -0.04 |    40.13 |   606 |        -0.04 |      40.13 |    606
 KHGX     | C_in    |      -0.59 |    39.97 |  1400 |        -0.59 |      39.97 |   1400
 KHTX     | C_in    |      -0.92 |    39.68 |  3812 |        -0.92 |      39.68 |   3812
 KJAX     | C_in    |      -2.02 |    40.71 |  2965 |        -2.02 |      40.71 |   2965
 KJGX     | C_in    |      -0.92 |    40.09 |  2533 |        -0.92 |      40.09 |   2533
 KLCH     | C_in    |      -2.59 |     41.9 |  1177 |        -2.59 |       41.9 |   1177
 KLIX     | C_in    |      -2.19 |     41.9 |  1602 |        -2.19 |       41.9 |   1602
 KMLB     | C_in    |       0.67 |    38.29 |  1574 |         0.67 |      38.29 |   1574
 KMOB     | C_in    |       0.41 |    38.77 |  1584 |         0.41 |      38.77 |   1584
 KSHV     | C_in    |      -1.77 |    40.65 |  2378 |        -1.77 |      40.65 |   2378
 KTBW     | C_in    |      -1.43 |    40.58 |  1572 |        -1.43 |      40.58 |   1572
 KTLH     | C_in    |      -2.56 |    39.61 |  1275 |        -2.56 |      39.61 |   1275
 KAMX     | S_above |      -1.59 |    25.34 |   511 |         -0.9 |      24.65 |    511
 KBMX     | S_above |      -2.23 |    26.68 |  4123 |        -1.42 |      25.87 |   4123
 KBRO     | S_above |      -2.82 |     26.5 |   479 |        -2.03 |      25.71 |    479
 KBYX     | S_above |      -0.71 |    24.49 |   229 |        -0.09 |      23.87 |    229
 KCLX     | S_above |      -1.66 |    26.04 |  3737 |        -0.91 |      25.29 |   3737
 KCRP     | S_above |      -1.11 |    24.93 |   298 |        -0.46 |      24.28 |    298
 KDGX     | S_above |      -1.59 |    26.35 |  2944 |        -0.82 |      25.57 |   2944
 KEVX     | S_above |       -0.7 |     25.5 |  1581 |         0.01 |      24.79 |   1581
 KFWS     | S_above |      -1.45 |    25.45 |  2059 |        -0.75 |      24.75 |   2059
 KGRK     | S_above |      -0.38 |    24.48 |   682 |         0.24 |      23.86 |    682
 KHGX     | S_above |      -1.38 |    26.11 |  1670 |        -0.63 |      25.36 |   1670
 KHTX     | S_above |      -1.65 |    26.41 |  6462 |        -0.86 |      25.62 |   6462
 KJAX     | S_above |      -2.81 |     27.1 |  2258 |        -1.96 |      26.25 |   2258
 KJGX     | S_above |      -0.93 |    26.04 |  3238 |        -0.17 |      25.28 |   3238
 KLCH     | S_above |      -2.05 |    26.28 |  1662 |        -1.27 |      25.51 |   1662
 KLIX     | S_above |      -2.33 |    26.34 |  3703 |        -1.56 |      25.56 |   3703
 KMLB     | S_above |       0.01 |    24.27 |   734 |         0.61 |      23.67 |    734
 KMOB     | S_above |      -0.11 |    24.42 |  1902 |         0.51 |       23.8 |   1902
 KSHV     | S_above |       -2.5 |    26.32 |  2350 |        -1.72 |      25.55 |   2350
 KTBW     | S_above |      -1.94 |    25.75 |  1016 |        -1.22 |      25.02 |   1016
 KTLH     | S_above |      -2.96 |    27.16 |  2239 |        -2.11 |      26.31 |   2239
 KAMX     | S_below |      -0.81 |    33.35 |  2618 |        -1.92 |      34.45 |   2618
 KBMX     | S_below |      -0.85 |    31.67 |  1681 |        -1.82 |      32.64 |   1681
 KBRO     | S_below |      -1.34 |    29.87 |  1247 |        -2.16 |      30.69 |   1247
 KBYX     | S_below |      -0.27 |    30.99 |  3288 |        -1.18 |       31.9 |   3288
 KCLX     | S_below |      -0.52 |    31.49 |  3080 |        -1.47 |      32.45 |   3080
 KCRP     | S_below |      -0.35 |    30.38 |  1040 |        -1.21 |      31.24 |   1040
 KDGX     | S_below |      -1.24 |    30.68 |  5083 |        -2.13 |      31.57 |   5083
 KEVX     | S_below |       1.05 |    32.02 |  2152 |         0.05 |      33.02 |   2152
 KFWS     | S_below |       0.82 |    28.52 |  1041 |         0.11 |      29.23 |   1041
 KGRK     | S_below |       0.82 |    29.92 |   122 |           -0 |      30.75 |    122
 KHGX     | S_below |       0.97 |    33.24 |  2179 |        -0.12 |      34.34 |   2179
 KHTX     | S_below |       0.35 |    30.68 |  2796 |        -0.54 |      31.57 |   2796
 KJAX     | S_below |       0.22 |    32.22 |  3203 |         -0.8 |      33.23 |   3203
 KJGX     | S_below |       1.08 |    33.22 |  2763 |        -0.02 |      34.32 |   2763
 KLCH     | S_below |      -0.96 |     30.9 |   890 |        -1.86 |       31.8 |    890
 KLIX     | S_below |       -1.4 |    32.54 |  1774 |        -2.44 |      33.58 |   1774
 KMLB     | S_below |       2.43 |    29.24 |  1326 |         1.67 |      30.01 |   1326
 KMOB     | S_below |      -0.16 |    30.97 |  1492 |        -1.07 |      31.88 |   1492
 KSHV     | S_below |      -1.47 |    30.74 |  1189 |        -2.36 |      31.63 |   1189
 KTBW     | S_below |      -0.71 |     31.3 |  1965 |        -1.65 |      32.24 |   1965
 KTLH     | S_below |      -2.32 |    33.55 |  1819 |        -3.45 |      34.68 |   1819
 KAMX     | S_in    |      -1.72 |    33.01 |  3545 |        -1.72 |      33.01 |   3545
 KBMX     | S_in    |      -2.48 |    32.34 | 15266 |        -2.48 |      32.34 |  15266
 KBRO     | S_in    |      -2.52 |    31.76 |  2644 |        -2.52 |      31.76 |   2644
 KBYX     | S_in    |      -1.25 |     32.1 |  4003 |        -1.25 |       32.1 |   4003
 KCLX     | S_in    |      -2.43 |    33.27 | 11813 |        -2.43 |      33.27 |  11813
 KCRP     | S_in    |       -1.4 |    30.81 |  2179 |         -1.4 |      30.81 |   2179
 KDGX     | S_in    |      -2.21 |    32.18 | 13800 |        -2.21 |      32.18 |  13800
 KEVX     | S_in    |      -0.48 |    32.61 |  8030 |        -0.48 |      32.61 |   8030
 KFWS     | S_in    |      -1.41 |    29.99 |  5525 |        -1.41 |      29.99 |   5525
 KGRK     | S_in    |      -1.38 |    30.22 |   711 |        -1.38 |      30.22 |    711
 KHGX     | S_in    |      -1.09 |    32.74 |  4455 |        -1.09 |      32.74 |   4455
 KHTX     | S_in    |      -1.94 |    32.69 | 23950 |        -1.94 |      32.69 |  23950
 KJAX     | S_in    |      -1.99 |    33.09 |  9429 |        -1.99 |      33.09 |   9429
 KJGX     | S_in    |      -1.37 |    33.71 | 16037 |        -1.37 |      33.71 |  16037
 KLCH     | S_in    |      -2.88 |    34.64 |  4335 |        -2.88 |      34.64 |   4335
 KLIX     | S_in    |      -2.96 |    33.56 |  6498 |        -2.96 |      33.56 |   6498
 KMLB     | S_in    |       0.25 |    30.73 |  3061 |         0.25 |      30.73 |   3061
 KMOB     | S_in    |      -1.62 |    32.08 |  7445 |        -1.62 |      32.08 |   7445
 KSHV     | S_in    |      -2.64 |    32.39 |  5668 |        -2.64 |      32.39 |   5668
 KTBW     | S_in    |      -2.11 |    32.36 |  4438 |        -2.11 |      32.36 |   4438
 KTLH     | S_in    |      -3.32 |    33.64 |  7397 |        -3.32 |      33.64 |   7397
(126 rows)
