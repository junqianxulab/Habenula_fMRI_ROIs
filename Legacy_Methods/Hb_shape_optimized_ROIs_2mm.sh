#!/bin/bash
# Created by Ely, updated 9 June 2017. Creates shape-optimized Hb ROIs at 2mm functional resolution.
# Note: recommended to use main Habenula_fMRI_ROIs.sh script instead, which is based on this script but has improved functionality.

# Example command to run for a single subject:
# sh Hb_shape_optimized_ROIs.sh <subject_ID>

# Example LSF command to run in parallel for 100 subjects:
# bsub -J Hb_shapeopt[1-100] -P <account_name>  -q <queue> -n 1 -W 00:15 -R rusage[mem=8000] -R span[hosts=1] -o <logfile_basename>.%I.log -e <error_logfile_basename>.%I.err sh Hb_shape_optimized_ROIs.sh

home="/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP" # change to suit your environment
sublist="$home/sublists/sublist.txt" # list of subject IDs, one per line
indir="$home/MNI_ROIs/Hb_seg/zipped" # directory containing Hb segmentations at anatomical resolution (should match space of functional data, e.g. MNI, native)

# determine if single-subject or parallel
if [ -z $1 ] ; then
        sub=`head -n $LSB_JOBINDEX $sublist | tail -n 1`
else
        sub=$1
fi

workdir="$home/MNI_ROIs/Hb_shapeopt/$sub"
mkdir -p $workdir

cd $home


# perform downsampling
for dir in right left ; do
	invol=$indir/${sub}_${dir}_segHb_MNI_prob.nii.gz
	
	# define relatively large search region near Hb with unique value for each voxel
	fslmaths $home/MNI_ROIs/Hb_volopt/${sub}_${dir}_volopt_Hb_MNI.nii.gz -kernel sphere 5 -dilD -index $workdir/${sub}_${dir}_index_2mm
	if [ $? -ne 0 ] ; then exit 42 ; fi
	
	# upsample indexed search region to anatomical resolution and match anatomical x y z dimensions
        flirt -in $workdir/${sub}_${dir}_index_2mm -applyxfm \
		-init $FSLDIR/etc/flirtsch/ident.mat \
		-out $workdir/${sub}_${dir}_index_0.7mm \
	       	-paddingsize 0.0 -interp nearestneighbour \
		-ref $home/MNI_ROIs/template_header_0.7mm
	if [ $? -ne 0 ] ; then exit 43 ; fi
	
	# create anatomical-resolution ROI masks. Can adjust thresholds up to make smaller shapeopt ROIs.
	fslmaths $invol -thr 0.25 -bin $workdir/mask_${dir}_0.7mm
	if [ $? -ne 0 ] ; then exit 44 ; fi
	
	# mask indexed anatomical-resolution region with Hb ROI mask
	fslmaths $workdir/${sub}_${dir}_index_0.7mm -mas $workdir/mask_${dir}_0.7mm $workdir/${sub}_${dir}_index_0.7mm_masked
	if [ $? -ne 0 ] ; then exit 45 ; fi

	# determine the highest-indexed voxel in the masked region
	bins=$(fslstats $workdir/${sub}_${dir}_index_0.7mm_masked -R | awk '{print $2}') 
	bins=${bins%.*} 
	echo "histogram bins = $bins"
	
	# determine how many voxels at each indexed value survived Hb ROI masking
	fslstats $workdir/${sub}_${dir}_index_0.7mm_masked -H $(( ${bins}+1 )) 0 $bins > $workdir/histogram_${dir}.txt
	if [ $? -ne 0 ] ; then exit 46 ; fi
	tally=0
	for (( i=2 ; i<=$bins+1 ; i++ )) ; do
		line=$(head -n $i $workdir/histogram_${dir}.txt | tail -n 1)
		line=${line%%.*}
		if [[ $line -ge 4 ]] ; then 
			# NB: Can adjust threshold down to create larger shapeopt ROIs
			echo $(( $i-1 )) $line >> $workdir/shapeopt_indices_${dir}.txt
			(( tally++ ))
		fi
       	done
	echo "$tally voxels identified"

	# create single-voxel masks for each voxel that survived Hb ROI masking
	mkdir -p $workdir/Hb_shapeopt_voxels_${dir}
	x=0
	for j in $(cat $workdir/shapeopt_indices_${dir}.txt | awk '{print $1}') ; do
		(( x++ ))
		weight=$(head -n $x $workdir/shapeopt_indices_${dir}.txt | tail -n 1 | awk '{print $2}')
		fslmaths $workdir/${sub}_${dir}_index_2mm -thr $j -uthr $j -bin -mul $weight $workdir/Hb_shapeopt_voxels_${dir}/$x
		if [ $? -ne 0 ] ; then exit 47 ; fi
	done

	# create final shapeopt Hb ROI
	fslmaths $workdir/${sub}_${dir}_index_2mm -mul 0 \
		$(echo $(for x in `ls $workdir/Hb_shapeopt_voxels_${dir}/*.gz` ; do echo -add $x ; done )) \
		$home/MNI_ROIs/Hb_shapeopt/${sub}_${dir}_shapeopt_Hb_MNI
	if [ $? -ne 0 ] ; then exit 48 ; fi
done

# combine bilateral ROIs
fslmaths $home/MNI_ROIs/Hb_shapeopt/${sub}_left_shapeopt_Hb_MNI -add $home/MNI_ROIs/Hb_shapeopt/${sub}_right_shapeopt_Hb_MNI $home/MNI_ROIs/Hb_shapeopt/${sub}_bilat_shapeopt_Hb_MNI
