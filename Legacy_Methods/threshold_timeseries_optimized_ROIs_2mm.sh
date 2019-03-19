#!/bin/bash
# Created by Benjamin Ely
# Version date 13 June 2017 
# Applies volume restriction to mean timeseries and pairwise timeseries optimized ROIs. Adapted from Hb_volume_optimized_ROIs_2mm.sh

# Example command to run for a single subject:
# sh threshold_timeseries_optimized_ROIs.sh <ROI_type> <subject_ID> <segmented_Hb_volume_in_mm>

# Example LSF command to run in parallel for 100 subjects:
# x=<ROItype> ; bsub -J Hb_volopt[1-100] -P <account_name>  -q <queue> -n 1 -W 00:15 -R rusage[mem=8000] -R span[hosts=1] -o <logfile_basename>.%I.log -e <error_logfile_basename>.%I.err sh threshold_timeseries_optimized_ROIs.sh $x

home="/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP"  # change to suit your environment
cd $home
sublist="$home/sublists/sublist.txt" # list of subject IDs, one per line

# determine if single-subject or parallel
if [ -z $1 ] ; then
        sub=`head -n $LSB_JOBINDEX $sublist | tail -n 1`
        i=$LSB_JOBINDEX
else
        sub=$1
        i=1
fi
roitype=$1

# perform iterative thresholding
for dir in left right ; do
        # requires input list of target number of voxels per subject/hemisphere. Can obtain by running $ fslstats ${sub}_volume_optimized_Hb_ROI.nii.gz -V | awk '{print $1}' >> target_voxels_2mm_${dir}.txt 
	target=`head -n $i $home/MNI_ROIs/target_voxels_2mm_${dir}.txt | tail -n 1`
	invol="$home/MNI_ROIs/Hb_$roitype/${sub}_${dir}_${roitype}_Hb_MNI_full"
	outvol="$home/MNI_ROIs/Hb_$roitype/${sub}_${dir}_${roitype}_Hb_MNI"
	doit=TRUE
	thresh="0.5"
	trend=""
	increment=".05"
	scale=10
	while [ $doit = "TRUE" ] ; do
		fslmaths $invol -thr ${thresh} -uthr 1.00001 $outvol
		if [ $? -ne 0 ] ; then exit 42 ; fi
		result=$(fslstats $outvol -V | awk '{print $1}')
		dif=$(echo "${target}-${result}" | bc)
		if [ $? -ne 0 ] ; then exit 43 ; fi
		echo -e "Subject $sub $dir thresh=$thresh\n target=$target\n result=$result\n dif=$dif"
		#echo "$thresh $target $result $dif" >> "$home/MNI_ROIs/Hb_$roitype/${sub}_${dir}_${roitype}_Hb_MNI_thresh.txt"
		echo "$thresh $target $result $dif" >> "$home/MNI_ROIs/Hb_$roitype/${sub}_${dir}_${roitype}_Hb_MNI_BP_CC_FIX_thresh.txt"
		if [[ ${dif} -eq 0 ]] ; then
			echo -e "Looks good!\n"
			doit=FALSE
		elif [[ ${dif} -gt 0 ]] ; then
			thresh=$(echo "${thresh}-${increment}" | bc)
			oldtrend=$trend
			trend="up"
			if [[ "$oldtrend" = "down" ]] ; then
				increment=$(echo "scale=$scale; ${increment}*0.2" | bc)
				if [ $? -ne 0 ] ; then exit 44 ; fi
				trend="down"
				(( $scale + 5 ))
				echo "WARNING: Redundant threshold test detected. Reducing increment to ${increment}"
			else
				echo "Low-res volume too small, incrementing thresh to $thresh"
			fi
		elif [[ ${dif} -lt 0 ]] ; then
			thresh=$(echo "${thresh}+${increment}" | bc)
			oldtrend=$trend
			trend="down"
			if [[ "$oldtrend" = "up" ]] ; then
				increment=$(echo "scale=$scale; ${increment}*0.2" | bc)
				if [ $? -ne 0 ] ; then exit 45 ; fi
				trend="up"
				(( $scale + 5 ))
				echo "WARNING:Redundant threshold test detected. Reducing increment to ${increment}"
			else
				echo "Low-res volume too large, incrementing thresh to $thresh"
			fi
		fi
	done
done

