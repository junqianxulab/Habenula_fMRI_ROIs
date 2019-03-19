#!/bin/bash
# Updated by Ely 18 Aug 2017 from par_MNI_extract_voxelwise_TS.sh.
# Extracts voxelwise and mean timeseries values from large, shape optimized Hb ROIs for use in timeseries-based ROI optimization.
# Suggested to run after fMRI preprocessing and denoising (e.g. ICA-FIX, CompCor, BandPass)

# Example command to run for a single subject:
# sh extract_voxelTS.sh <subject_ID>

# Example LSF command to run in parallel for 100 subjects:
# bsub -J extractTS[1-100] -P <account_name>  -q <queue> -n 1 -W 02:00 -R rusage[mem=40000] -R span[hosts=1] -o <logfile_basename>.%I.log sh extract_voxelTS.sh

home="/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP" # change to suit your environment
cd $home
sublist="$home/sublists/sublist.txt" # list of subject IDs, one per line
roidir="$home/MNI_ROIs" # parent directory for Hb ROI generation
outdir="$roidir/Hb_voxelTS" # output directory
maskdir="$roidir/Hb_shapeopt" # directory containing subject-level shape optimized Hb ROIs (or other input ROI region mask)

# determine if single-subject or parallel
if [ -z $1 ] ; then
        sub=`head -n $LSB_JOBINDEX $sublist | tail -n 1`
else
        sub=$1
fi

fMRIdata="$home/Subjects/$sub/${sub}_rfMRI_RESTall_hp2000_clean_BP_CC.nii.gz" # change to suit your environment

# perform timeseries extraction
for dir in left right ; do
	# extract voxelwise timeseries values
	fslmeants -i $fMRIdata -m $maskdir/${sub}_${dir}_shapeopt_Hb_MNI -o $outdir/${sub}_${dir}_Hb_shapeopt_voxelTS_BP_CC_FIX.txt --showall 2>&1
	if [ "$?" -ne "0" ] ; then exit 42 ; fi
	fslmeants -i $fMRIdata -m $maskdir/${sub}_${dir}_shapeopt_Hb_MNI -o $outdir/${sub}_${dir}_Hb_shapeopt_meanTS_BP_CC_FIX.txt 2>&1
	if [ "$?" -ne "0" ] ; then exit 43 ; fi
done

# extract mean bilateral Hb timeseries
fslmeants -i $fMRIdata -m $maskdir/${sub}_bilat_shapeopt_Hb_MNI -o $outdir/${sub}_bilat_Hb_shapeopt_meanTS_BP_CC_FIX.txt 2>&1
if [ "$?" -ne "0" ] ; then exit 44 ; fi

# create destination folders for timeseries-based ROI optimizationn
mkdir -p $roidir/Hb_meanTSopt
mkdir -p $roidir/Hb_pairTSopt
