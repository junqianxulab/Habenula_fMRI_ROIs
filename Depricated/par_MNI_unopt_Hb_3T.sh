#!/bin/bash
# Created by Ely 8 June 2017. Runs FSL nearest-neighbour downsampling of Hb ROIs to 2mm resolution. Use in conjunction an LSF command like:
# bsub -J Hb_unopt[1-68] -P acc_sterne04a -q expressalloc -n 1 -W 00:15 -R rusage[mem=8000] -R span[hosts=1] -o /sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP/logs/ROI_gen_unopt/unopt_3T.%I.log -L /bin/bash sh /sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP/MNI_ROIs/scripts/par_MNI_unopt_Hb_3T.sh

home="/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP"
sublist="$home/sublists/sublist.txt"
indir="$home/MNI_ROIs/Hb_seg"
outdir="$home/MNI_ROIs/Hb_unopt"
cd $home
sub=`head -n $LSB_JOBINDEX $sublist | tail -n 1`
for dir in left right ; do
	invol="${sub}_${dir}_segHb_MNI"
	outvol="${sub}_${dir}_unopt_Hb_MNI"
	flirt -interp nearestneighbour -in $indir/$invol -ref $HOME/templates/HCP_Pipeline_templates/MNI152_T1_2mm -out $outdir/$outvol -applyisoxfm 2 2>&1
	if [ $? -ne 0 ] ; then exit 42 ; fi
done
fslmaths $outdir/${sub}_left_unopt_Hb_MNI -add $outdir/${sub}_right_unopt_Hb_MNI $outdir/${sub}_bilat_unopt_Hb_MNI
if [ $? -ne 0 ] ; then exit 43 ; fi
