#!/bin/bash
#grep -Eo "ds:tmp ['\"a-z_]+" .commands.sh | ds:reo a 2 -v FS=" " | sed "s:['\\\"]::g" | ds:fc | ds:reo a 2 | sed 's/$/.*/g' | sed 's:^:/tmp/:g' | sort | ds:mini " " >> $DS_SUPPORT/clean.sh
#echo 'Removed ds tmp files.'

rm /tmp/ds_complements.* /tmp/ds_deps.* /tmp/ds_dup_input.* /tmp/ds_fc_dequote.* /tmp/ds_fieldcounts.* /tmp/ds_fit.* /tmp/ds_fit_dequote.* /tmp/ds_fsrc.* /tmp/ds_git_recent_all.* /tmp/ds_gvi.* /tmp/ds_hist.* /tmp/ds_idx.* /tmp/ds_inferk.* /tmp/ds_jn.* /tmp/ds_mactounix.* /tmp/ds_matches.* /tmp/ds_mini.* /tmp/ds_ndata.* /tmp/ds_newfs.* /tmp/ds_newfs_dequote.* /tmp/ds_pipe_check.* /tmp/ds_pow.* /tmp/ds_pow_dequote.* /tmp/ds_reo.* /tmp/ds_reo_dequote.* /tmp/ds_sbsp.* /tmp/ds_select.* /tmp/ds_selectsource.* /tmp/ds_sort.* /tmp/ds_sortm.* /tmp/ds_stagger.* /tmp/ds_tmp_dequote.* /tmp/ds_transpose.* /tmp/ds_transpose_dequote.* 2>/dev/null

