#!/bin/bash
# Ely 1/18/2017
# Copies correct header info to argument ROIs generated from Matlab
# Run after Hb_mean_timeseries_optimized_ROIs.m and again after Hb_pairwise_timeseries_optimized_ROIs.m

# Example command to run for all subjects for mean timeseries optimized
# sh correct_matlab_headers.sh meanTSopt

home="/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP" # change to suit your environment
cd $home
sublist="$home/sublists/sublist.txt" # list of subject IDs, one per line
target="$home/MNI_ROIs/template_header_2mm.nii.gz" # NIFTI file matching your fMRI resolution and XYZ dimensions
for sub in `cat $sublist` ; do
	fslcpgeom $target $home/MNI_ROIs/Hb_${1}/${sub}_left_${1}_Hb_MNI_BP_CC_FIX_full.nii
	if [ $? -ne 0 ] ; then exit 42 ; fi
	fslcpgeom $target $home/MNI_ROIs/Hb_${1}/${sub}_right_${1}_Hb_MNI_BP_CC_FIX_full.nii
	if [ $? -ne 0 ] ; then exit 43 ; fi
	echo "Subject $sub $1 headers fixed"
done

