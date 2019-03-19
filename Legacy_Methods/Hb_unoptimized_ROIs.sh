#!/bin/bash
# Created by Ely 8 June 2017. Performs basic downsampling of anatomical Hb segmentations to create subject-level Hb ROIs at functional resolution. 

# Example command to run for a single subject:
# sh Hb_unoptimized_ROIs.sh <subject_ID>

# Example LSF command to run in parallel for 100 subjects:
# bsub -J Hb_unopt[1-100] -P <account_name>  -q <queue> -n 1 -W 00:15 -R rusage[mem=8000] -R span[hosts=1] -o <logfile_basename>.%I.log sh Hb_unoptimized_ROIs.sh

home="/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP" # change to suit your environment
template="$HOME/templates/HCP_Pipeline_templates/MNI152_T1_2mm" # example NIFTI file matching the spatial resolution/dimensions of your functional data
funcres="2" # resolution of functional data, in mm (must be isotropic)
sublist="$home/sublists/sublist.txt" # list of subject IDs, one per line
indir="$home/MNI_ROIs/Hb_seg" # directory containing Hb segmentations at anatomical resolution (should match space of functional data, e.g. MNI, native)
outdir="$home/MNI_ROIs/Hb_unopt" # directory for output functional-resolution Hb ROIs
cd $home

# determine if single-subject or parallel
if [ -z $1 ] ; then
	sub=`head -n $LSB_JOBINDEX $sublist | tail -n 1`
else
	sub=$1
fi

# perform downsampling
for dir in left right ; do
	invol="${sub}_${dir}_segHb_MNI"
	outvol="${sub}_${dir}_unopt_Hb_MNI"
	flirt -interp nearestneighbour -in $indir/$invol -ref $template -out $outdir/$outvol -applyisoxfm $funcres 2>&1
	if [ $? -ne 0 ] ; then exit 42 ; fi
done
fslmaths $outdir/${sub}_left_unopt_Hb_MNI -add $outdir/${sub}_right_unopt_Hb_MNI $outdir/${sub}_bilat_unopt_Hb_MNI
if [ $? -ne 0 ] ; then exit 43 ; fi
