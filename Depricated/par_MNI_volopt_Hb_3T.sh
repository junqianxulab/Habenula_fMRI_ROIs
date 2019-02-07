#!/bin/bash
# Created by Ely, updated 6/5/2017. Runs volume optimization on Hb ROIs. Use in conjunction an LSF command like:
# bsub -J Hb_volopt[1-68] -P acc_sterne04a -q expressalloc -n 1 -W 00:15 -R rusage[mem=8000] -R span[hosts=1] -o /sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP/logs/ROI_gen_volopt/volopt.%I.out -e /sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP/logs/ROI_gen_volopt/volopt.%I.err -L /bin/bash sh /sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP/MNI_ROIs/scripts/par_MNI_volopt_Hb_3T.sh

home="/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP"
sublist="$home/sublists/sublist.txt"
direction="right left"
indir="$home/MNI_ROIs/Hb_seg"
outdir="$home/MNI_ROIs/Hb_volopt"
i=$LSB_JOBINDEX
cd $home
sub=`head -n $LSB_JOBINDEX $sublist | tail -n 1`
for dir in $direction ; do
	invol="${sub}_${dir}_segHb_MNI_prob"
	echo "invol=$invol"
	doit=TRUE
	thresh="0.5"
	trend=""
	increment=".05"
	target=`head -n $LSB_JOBINDEX $indir/final_Hb_volume_partial_${dir}.txt | tail -n 1`
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
