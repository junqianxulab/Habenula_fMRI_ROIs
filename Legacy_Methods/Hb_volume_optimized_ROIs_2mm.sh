#!/bin/bash
# Created by Ely, updated 6/5/2017. Generates subject-level Hb ROIs at functional resolution optimized to match the volume of the input probabilistic Hb segmentations (see Kim JW et al. NeuroImage 2016).

# Example command to run for a single subject:
# sh Hb_volume_optimized_ROIs.sh <subject_ID> <segmented_Hb_volume_in_mm>

# Example LSF command to run in parallel for 100 subjects:
# bsub -J Hb_volopt[1-100] -P <account_name>  -q <queue> -n 1 -W 00:15 -R rusage[mem=8000] -R span[hosts=1] -o <logfile_basename>.%I.log -e <error_logfile_basename>.%I.err sh Hb_volume_optimized_ROIs.sh

home="/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP" # change to suit your environment
sublist="$home/sublists/sublist.txt" # list of subject IDs, one per line
direction="right left"
indir="$home/MNI_ROIs/Hb_seg" # directory containing probabilistic Hb segmentations at anatomical resolution and a text file containing estimated Hb segmentation volume
outdir="$home/MNI_ROIs/Hb_volopt"  # directory for output functional-resolution Hb ROIs
cd $home

# determine if single-subject or parallel
if [ -z $1 ] ; then
        sub=`head -n $LSB_JOBINDEX $sublist | tail -n 1`
	i=$LSB_JOBINDEX
else
        sub=$1
	i=1
fi

# perform iterative downsampling with volume matching
for dir in $direction ; do
	invol="${sub}_${dir}_segHb_MNI_prob"
	echo "invol=$invol"
	doit=TRUE
	thresh="0.5"
	trend=""
	increment=".05"
	# determine target volume
	vollist="$indir/final_Hb_volume_partial_${dir}.txt" # text file containing estimated Hb segmentation volumes in mm (one value if running for single-subject, one per line if running in parallel)
	target=`head -n $i $vollist | tail -n 1`
	echo "target_volume=$target"
	while [ $doit = "TRUE" ] ; do
		thrname=$(echo "${thresh}*100" | bc)
		hires_thr="${invol}_thr${thrname%.*}"
		lowres_thr="${hires_thr}_2mm"
		echo "hires_thr=$hires_thr"
		echo "lowres_thr=$lowres_thr"
		if [[ $(echo "if (${thresh} < 0) 1 else 0" | bc) -eq 1 || $(echo "if (${thresh} > 1) 1 else 0" | bc) -eq 1 ]] ; then
			echo "Error: threshold beyond partial volume range"
			echo "error_out_of_range" >> "$outdir/${sub}_${dir}_MNI_downsample_thresholding.txt"
			exit 42
		fi
		fslmaths $indir/$invol -thr ${thresh} $outdir/$hires_thr
		flirt -interp nearestneighbour -in $outdir/$hires_thr -ref $HOME/templates/HCP_Pipeline_templates/MNI152_T1_2mm -applyisoxfm 2 -out $outdir/$lowres_thr
		result=$(echo $(fslstats $outdir/$lowres_thr -V) | cut -d " " -f2- )
		echo "result=$result"
		dif=$(echo "${target}-${result}" | bc)
		echo -e "Subject $sub $dir thresh=$thresh\n target=$target\n result=$result\n dif=$dif"
		echo "$thresh $target $result $dif" >> "$outdir/${sub}_${dir}_MNI_downsample_thresholding.txt"
		if [[ $(echo "if (${dif} <= 4) 1 else 0" | bc) -eq 1 && $(echo "if (${dif} >= -4) 1 else 0" | bc) -eq 1 ]] ; then
			echo -e "Looks good!\n"
			doit=FALSE
		elif [[ $(echo "if (${dif} > 4) 1 else 0" | bc) -eq 1 ]] ; then
			imrm $outdir/${hires_thr}
			imrm $outdir/${lowres_thr}
			thresh=$(echo "${thresh}-${increment}" | bc)
			oldtrend=$trend
			trend="up"
			if [[ "$oldtrend" = "down" ]] ; then
				increment=$(echo "${increment}*0.2000" | bc)
				trend="down"
				echo "Warning: redundant threshold test. Reducing increment to ${increment}"
			else
				echo "Low-res volume too small, incrementing thresh to $thresh"
			fi
		elif [[ $(echo "if (${dif} < -4) 1 else 0" | bc) -eq 1 ]] ; then
			imrm $outdir/${hires_thr}
			imrm $outdir/${lowres_thr}
			thresh=$(echo "${thresh}+${increment}" | bc)
			oldtrend=$trend
			trend="down"
			if [[ "$oldtrend" = "up" ]] ; then
				increment=$(echo "${increment}*0.2000" | bc)
				trend="up"
				echo "Warning: redundant threshold test. Reducing increment to ${increment}"
			else
				echo "Low-res volume too large, incrementing thresh to $thresh"
			fi
		fi
	done
done
