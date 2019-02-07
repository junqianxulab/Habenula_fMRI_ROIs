#!/bin/bash
# Ely 1/18/2017
# Copies correct header info to argument ROI generated from Matlab

home="/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP"
cd $home
sublist="$home/sublists/sublist.txt"
for sub in `cat $sublist` ; do
	fslcpgeom $home/MNI_ROIs/template_header_2mm.nii.gz $home/MNI_ROIs/Hb_${1}/${sub}_left_${1}_Hb_MNI_BP_CC_FIX_full.nii
	if [ $? -ne 0 ] ; then exit 42 ; fi
	fslcpgeom $home/MNI_ROIs/template_header_2mm.nii.gz $home/MNI_ROIs/Hb_${1}/${sub}_right_${1}_Hb_MNI_BP_CC_FIX_full.nii
	if [ $? -ne 0 ] ; then exit 43 ; fi
	
	echo "Subject $sub complete"
done

