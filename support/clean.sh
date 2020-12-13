#!/bin/bash
#grep -Eo "ds:tmp ['\"a-z_]+" commands.sh | ds:reo a 2 -v FS=" " | sed "s:['\\\"]::g" | ds:fc | ds:reo a 2 | sed 's/$/.*/g' | sed 's:^:/tmp/:g' | rg -v filename | sort | ds:mini " " >> $DS_SUPPORT/clean.sh; echo >> $DS_SUPPORT/clean.sh
#echo 'Removed dev_scripts tmp files.'

rm /tmp/ds_agg.* /tmp/ds_agg_prefield.* /tmp/ds_case.* /tmp/ds_decap.* /tmp/ds_deps.* /tmp/ds_dostounix.* /tmp/ds_dup_input.* /tmp/ds_enti.* /tmp/ds_extractfs.* /tmp/ds_fc_prefield.* /tmp/ds_fd.* /tmp/ds_fieldcounts.* /tmp/ds_fsrc.* /tmp/ds_git_recent_all.* /tmp/ds_graph.* /tmp/ds_graph_prefield.* /tmp/ds_gvi.* /tmp/ds_hist.* /tmp/ds_idx.* /tmp/ds_jn.* /tmp/ds_jn_prefield.* /tmp/ds_line.* /tmp/ds_mini.* /tmp/ds_ndata.* /tmp/ds_newfs.* /tmp/ds_newfs_prefield.* /tmp/ds_pipe_check.* /tmp/ds_pivot.* /tmp/ds_pivot_prefield.* /tmp/ds_pow.* /tmp/ds_pow_prefield.* /tmp/ds_reo.* /tmp/ds_reo_prefield.* /tmp/ds_sbsp.* /tmp/ds_sbsp_prefield.* /tmp/ds_searchx.* /tmp/ds_select.* /tmp/ds_selectsource.* /tmp/ds_shape.* /tmp/ds_sort.* /tmp/ds_sortm.* /tmp/ds_src.* /tmp/ds_stagger.* /tmp/ds_tmp_prefield.* /tmp/ds_transpose.* /tmp/ds_transpose_prefield.* 2>/dev/null

