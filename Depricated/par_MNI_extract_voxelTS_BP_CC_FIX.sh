#!/bin/bash
# Updated by Ely 18 Aug 2017 from par_MNI_extract_voxelwise_TS.sh. Extracts Bandpass filtered (0.1-0.01Hz), CompCor denoised voxelwise timeseries from Hb region masks for use in ROI optimization. Use in conjunction an LSF command like:
# bsub -J extractTS[1-68] -P acc_sterne04a -q expressalloc -n 1 -W 02:00 -R rusage[mem=40000] -R span[hosts=1] -o /sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP/logs/ROI_gen_extractTS/extract_Hb_region_voxelwise_timeseres_3T_BP_CC_FIX.%I.log -L /bin/bash sh /sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP/MNI_ROIs/scripts/par_MNI_extract_voxelTS_BP_CC_FIX.sh

home="/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP"
cd $home
sublist="$home/sublists/sublist.txt"
outdir="$home/MNI_ROIs/Hb_TSregion"
maskdir="$home/MNI_ROIs/Hb_region"
sub=`head -n $LSB_JOBINDEX $sublist | tail -n 1 | awk '{ print $1}'`
#run=`head -n $LSB_JOBINDEX $sublist | tail -n 1 | awk '{ print $2}'`
fMRIdata="$home/Subjects/$sub/${sub}_rfMRI_RESTall_hp2000_clean_BP_CC.nii.gz"
for dir in left right ; do
	# extract voxelwise timeseries values
	fslmeants -i $fMRIdata -m $maskdir/${sub}_${dir}_region_Hb_MNI -o $outdir/${sub}_${dir}_Hb_region_voxelTS_BP_CC_FIX.txt --showall 2>&1
	if [ "$?" -ne "0" ] ; then exit 42 ; fi
	fslmeants -i $fMRIdata -m $maskdir/${sub}_${dir}_region_Hb_MNI -o $outdir/${sub}_${dir}_Hb_region_meanTS_BP_CC_FIX.txt 2>&1
	if [ "$?" -ne "0" ] ; then exit 43 ; fi
done

fslmeants -i $fMRIdata -m $maskdir/${sub}_bilat_region_Hb_MNI -o $outdir/${sub}_bilat_Hb_region_meanTS_BP_CC_FIX.txt 2>&1
if [ "$?" -ne "0" ] ; then exit 44 ; fi
# Next, run MNI_biopt.m Matlab scripts
