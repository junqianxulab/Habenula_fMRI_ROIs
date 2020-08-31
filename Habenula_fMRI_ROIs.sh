#!/bin/bash
# Generates shape-optimized Hb ROIs at functional resolution (or other lower-resolution targets, e.g. diffusion) in native or template space from anatomical Hb segmentations in native space.
# Created by Benjamin A. Ely
# kindly cite Ely BA et al. 2019 NeuroImage, "Detailed mapping of human habenula resting-state functional connectivity", https://doi.org/10.1016/j.neuroimage.2019.06.015
# see github README for usage, https://github.com/junqianxulab/Habenula_fMRI_ROIs
# Version date 25 Aug 2020

# functions to parse inputs
getopt1() {
	sopt="$1"
	shift 1
	for fn in $@ ; do
		if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
			echo ${fn#*=}
			return 0
		fi
	done
}
togopt1() {
	sopt="$1"
	shift 1
	for fn in $@ ; do
		if [ `echo $fn | grep -- "^${sopt}" | wc -w` -gt 0 ] ; then
			echo true
			return 0
		fi
	done
	echo false
	return 0
}

# function to split bilateral Hb seg inputs
splitLR() {
	# expects $1=segB $2=workdir
	xlen=$(fslval $1 dim1)
	xhalf=$(echo "$xlen/2" | bc)
	fslroi $1 $2/tmp_half 0 $xhalf 0 -1 0 -1
	fslmaths $2/tmp_half -mul 0 $2/tmp_zed
	fslmaths $2/tmp_zed  -add 1 $2/tmp_one
	fslmerge -x $2/tmp_mask_L $2/tmp_zed $2/tmp_one
	fslmerge -x $2/tmp_mask_R $2/tmp_one $2/tmp_zed
	fslmaths $2/tmp_mask_L -mul $1 $2/${1%.nii*}_L
	fslmaths $2/tmp_mask_R -mul $1 $2/${1%.nii*}_R
	imrm $2/tmp_half $2/tmp_zed $2/tmp_one $2/tmp_mask_L $2/tmp_mask_R
	return 0
}

# parse inputs
#	mandatory
sub=`   getopt1 "--sub"    $@`
func=`  getopt1 "--func"   $@`
odir=`  getopt1 "--odir"   $@`
segB=`  getopt1 "--segB"   $@`
#	or
segL=`  getopt1 "--segL"   $@`
segR=`  getopt1 "--segR"   $@`
#	optional
warp=`  getopt1 "--warp"   $@`
wdir=`  getopt1 "--wdir"   $@`
thresh=`getopt1 "--thresh" $@`
bin=`   togopt1 "--bin"    $@`
quiet=` togopt1 "--quiet"  $@`
LRout=` togopt1 "--LRout"  $@`

# create working directory inside output directory if not specified
if [ -z $wdir ] ; then
	workdir="$odir/${sub}_Hb_ROI_workdir"
else
	workdir=$wdir
fi
mkdir -p $workdir

# set up logging
logfile="$workdir/${sub}_Hb_ROI_gen.log"
if [ "$quiet" = "true" ] ; then
	logdisp='/dev/null'
else
	logdisp='/dev/tty'
fi

# set output threshold to exclude voxels low Hb content (default = 0.25, recommended for HCP data, may want to adjust for other datasets)
if [ -z $thresh ] ; then
	thresh="0.25"
fi

echo "`date`: subject $sub Hb ROI creation started" | tee -a $logfile > $logdisp
echo "`date`: subject $sub Hb ROI working directory set to $workdir" | tee -a $logfile > $logdisp
if ls $workdir/${sub}_full_index_func* > /dev/null 2>&1 ; then
	echo "`date`: WARNING: subject $sub re-run detected, old files will be overwritten/removed" | tee -a $logfile > $logdisp
fi

# if using segB, split into segL and segR
if [ ! -z $segB ] && [ ! -z ${segL}${segR} ] ; then
	echo "ERROR: either segB or segL+segR should be specified, not both" | tee -a $logfile > $logdisp
	exit 40
elif [ ! -z $segB ] && [ -z ${segL}${segR} ] ; then
	splitLR $segB $workdir
	if [ $? -ne 0 ] ; then exit 41 ; fi
	segR=$workdir/${segB%.nii*}_R
	segL=$workdir/${segB%.nii*}_L
	echo "`date`: subject $sub bilateral Hb segmentation split into left/right" | tee -a $logfile > $logdisp
fi

# create regularly-spaced index at functional resolution in target space
fslmaths -dt int $func -mul 0 -Tmean -add 1 -index $workdir/${sub}_full_index_func -odt int

# upsample index to anatomical resolution and optionally warp to native space
if [ -z $warp ] ; then
	applywarp -i $workdir/${sub}_full_index_func \
		  -r $segL \
		  -o $workdir/${sub}_full_index_anat \
	          --rel	\
		  --interp=nn # NB nearest neighbor interpolation to preserve exact index values
else
	applywarp -i $workdir/${sub}_full_index_func \
		  -r $segL \
		  -o $workdir/${sub}_full_index_anat \
		  -w $warp \
	          --rel	\
		  --interp=nn
fi
if [ $? -ne 0 ] ; then exit 42 ; fi
echo "`date`: subject $sub anatomical and functional indices created" | tee -a $logfile > $logdisp

for hemi in L R ; do
	
	if [ "$hemi" = "L" ] ; then seg=$segL ; else seg=$segR ; fi
	segname=$(basename $seg)
	segname=${segname%.nii*}

	# determine the maximum value in the segmentation and rescale to 1 if needed
	segmax=$(fslstats $seg -R | awk '{print $2}')
	if [[ $segmax > 1.000000 ]] ; then
		fslmaths $seg -div $segmax $workdir/${segname}_max1
		seg=$workdir/${segname}_max1
		echo "`date`: WARNING: subject $sub $hemi Hb segmentation has max of $segmax > 1, rescaled to max of 1" | tee -a $logfile > $logdisp
	fi

	# threshold slightly to remove interpolation artifacts etc
	segmin=$(fslstats $seg -R | awk '{print $1}')
	if [[ $segmin < 0 ]] ; then
		echo "`date`: WARNING: subject $sub $hemi Hb segmentation has min of $segmin < 0, values below 0.05 will be ignored" | tee -a $logfile > $logdisp
	fi
	fslmaths $seg -thr 0.05 $workdir/${segname}_max1_min0.05
	seg=$workdir/${segname}_max1_min0.05

	# mask warped index with Hb
	fslmaths $workdir/${sub}_full_index_anat -mas $seg $workdir/${sub}_${hemi}_Hb_index_anat
	if [ $? -ne 0 ] ; then exit 43 ; fi
	echo "`date`: subject $sub index masked with $hemi Hb segmentation" | tee -a $logfile > $logdisp

	# determine the highest-indexed voxel in the masked region
	bins=$(fslstats $workdir/${sub}_${hemi}_Hb_index_anat -R | awk '{print $2}') 
	if [ $? -ne 0 ] ; then exit 44 ; fi
	bins=${bins%.*} 
	
	# create histogram to determine how many voxels at each indexed value survived Hb ROI masking
	fslstats $workdir/${sub}_${hemi}_Hb_index_anat -H $(( ${bins}+1 )) 0 $bins > $workdir/${sub}_histogram_${hemi}.txt
	if [ $? -ne 0 ] ; then exit 45 ; fi
	echo "`date`: subject $sub $hemi histogram created with $bins bins" | tee -a $logfile > $logdisp
	
	# find indices (one-based) and nonzero counts of all voxel intensities
	cat -ns $workdir/${sub}_histogram_${hemi}.txt | grep .000000 | grep -v "\s0.000000" > $workdir/${sub}_tmp1_ShapeOpt_indices_${hemi}.txt
	
	# trim to remove voxels with zero intensity
	len=$( wc -l < $workdir/${sub}_tmp1_ShapeOpt_indices_${hemi}.txt )
	len=$(( ${len}-1 ))
	tail -n $len $workdir/${sub}_tmp1_ShapeOpt_indices_${hemi}.txt > $workdir/${sub}_tmp2_ShapeOpt_indices_${hemi}.txt
	
	# shift index values down one to match original zero-indexing and trim trailing zeroes from voxel counts
	if [ -e "$workdir/${sub}_ShapeOpt_indices_${hemi}.txt" ] ; then
		# remove old ShapeOpt indices list if re-running
		rm $workdir/${sub}_ShapeOpt_indices_${hemi}.txt
	fi
	for (( i=1 ; i<=$len ; i++ )) ; do
		j=$(head -n $i $workdir/${sub}_tmp2_ShapeOpt_indices_${hemi}.txt | tail -n 1 | awk '{print $1}') 
		k=$(head -n $i $workdir/${sub}_tmp2_ShapeOpt_indices_${hemi}.txt | tail -n 1 | awk '{print $2}')
		j=$(( ${j}-1 ))
		echo $j ${k%%.*} >> $workdir/${sub}_ShapeOpt_indices_${hemi}.txt
	done
	rm $workdir/${sub}_tmp1_ShapeOpt_indices_${hemi}.txt
	rm $workdir/${sub}_tmp2_ShapeOpt_indices_${hemi}.txt
	echo "`date`: subject $sub $len $hemi nonzero indices identified" | tee -a $logfile > $logdisp
	
	# create single-voxel masks for each voxel that survived Hb ROI masking
	mkdir -p $workdir/${sub}_Hb_ShapeOpt_voxels_${hemi}
	x=0
	for j in $(cat $workdir/${sub}_ShapeOpt_indices_${hemi}.txt | awk '{print $1}') ; do
		(( x++ ))
		# find number of anatomical voxels at current index
		weight=$(head -n $x $workdir/${sub}_ShapeOpt_indices_${hemi}.txt | tail -n 1 | awk '{print $2}')
		echo "`date`: subject $sub $hemi voxel $x actual occurances in masked region = $weight" | tee -a $logfile > $logdisp
		# define upper and lower thresholds
		lthr=$(echo "$j - 0.1" | bc)
		uthr=$(echo "$j + 0.1" | bc)
		# find maximum possible number of anatomical voxels at each index
		max=$(fslstats $workdir/${sub}_full_index_anat -l $lthr -u $uthr -V | awk '{print $1}')
		echo "`date`: subject $sub $hemi voxel $x possible occurances in masked region = $max" | tee -a $logfile > $logdisp
		# create mask with only current index values
		fslmaths $workdir/${sub}_${hemi}_Hb_index_anat -thr $j -uthr $j $workdir/${sub}_Hb_ShapeOpt_voxels_${hemi}/mask_anat_$x
		if [ $? -ne 0 ] ; then exit 46 ; fi
		# find average Hb probability of anatomical voxels at current index based on probabilistic segmentation
		prob=$(fslstats $seg -k $workdir/${sub}_Hb_ShapeOpt_voxels_${hemi}/mask_anat_$x -M)
		echo "`date`: subject $sub $hemi voxel $x mean probability in segmentation = $prob" | tee -a $logfile > $logdisp
		# weight functional-resolution voxel for current index by average probability and fraction of possible voxels at that index included in the segmented Hb
		fslmaths $workdir/${sub}_full_index_func -thr $lthr -uthr $uthr -bin -mul $weight -div $max -mul $prob $workdir/${sub}_Hb_ShapeOpt_voxels_${hemi}/voxel_func_$x
		if [ $? -ne 0 ] ; then exit 47 ; fi
		echo "`date`: subject $sub $hemi voxel $x of $len complete" | tee -a $logfile > $logdisp
	done

	# create weighted Hb ShapeOpt ROI
	fslmaths $workdir/${sub}_full_index_func -mul 0 \
		 $(echo $(for x in `ls $workdir/${sub}_Hb_ShapeOpt_voxels_${hemi}/voxel_func*.nii.gz` ; do echo -add $x ; done )) \
		 $workdir/${sub}_${hemi}_Hb_ShapeOpt_func_unscaled
	if [ $? -ne 0 ] ; then exit 48 ; fi
	echo "`date`: subject $sub $hemi probabilistic Hb ShapeOpt ROI created" | tee -a $logfile > $logdisp

	# scale Hb ShapeOpt ROI weights to between 0 and 1 and threshold slightly to remove noise
	min=$(fslstats $workdir/${sub}_${hemi}_Hb_ShapeOpt_func_unscaled -l 0.000001 -R | awk '{print $1}')
	max=$(fslstats $workdir/${sub}_${hemi}_Hb_ShapeOpt_func_unscaled -R | awk '{print $2}') 
	fslmaths $workdir/${sub}_${hemi}_Hb_ShapeOpt_func_unscaled \
		 -sub $min \
		 -div $(echo ${max}-${min} | bc) \
		 -thr 0.01 \
		 $workdir/${sub}_Hb_ROI_ShapeOpt_full_${hemi}
	if [ $? -ne 0 ] ; then exit 49 ; fi
	echo "`date`: subject $sub $hemi Hb ShapeOpt ROI probability scaled from $min = 0 to 0$(echo ${max}-${min} | bc) = 1" | tee -a $logfile > $logdisp
done

# combine left/right ROIs
fslmaths      $workdir/${sub}_Hb_ROI_ShapeOpt_full_L \
	 -add $workdir/${sub}_Hb_ROI_ShapeOpt_full_R \
	      $workdir/${sub}_Hb_ROI_ShapeOpt_full_B
if [ $? -ne 0 ] ; then exit 50 ; fi
echo "`date`: subject $sub bilateral probabilistic Hb ShapeOpt ROI created" | tee -a $logfile > $logdisp

# check for overlap between left and right Hb ROIs; this is uncommon but may be a concern due to CSF medial to Hb
fslmaths $workdir/${sub}_Hb_ROI_ShapeOpt_full_B -mas $workdir/${sub}_Hb_ROI_ShapeOpt_full_L -mas $workdir/${sub}_Hb_ROI_ShapeOpt_full_R $workdir/${sub}_Hb_ROI_ShapeOpt_full_overlap_LR
overlapVox=$(fslstats $workdir/${sub}_Hb_ROI_ShapeOpt_full_overlap_LR -V | awk '{print $1}')
if [ $overlapVox -ne 0 ] ; then
	overlapMax=$(fslstats $workdir/${sub}_Hb_ROI_ShapeOpt_full_overlap_LR -R | awk '{print $2}')
	echo "`date`: WARNING: subject $sub L and R Hb ShapeOpt ROIs overlap by $overlapVox voxels. Overlapping voxel weights will be summed in the bilateral ROI, which may increase CSF signal contamination if using the full weighted/unthresholded Hb ROI. Max combined weight of overlapping voxels = $overlapMax " | tee -a $logfile > $logdisp
	if (( $(echo "$overlapMax >= $thresh" | bc) )) ; then
		echo "ERROR: max combined weight of overlapping voxels (${overlapMax}) exceeds the ROI threshold (${thresh}). This is likely due to a segmentation issue and will affect the final ShapeOpt ROI. Review inputs and adjust thresholds if needed." | tee -a $logfile > $logdisp
		exit 51
	fi
fi

for hemi in L R B ; do
	# optionally binarize outputs
	if [ "$bin" = "true" ] ; then
		fslmaths $workdir/${sub}_Hb_ROI_ShapeOpt_full_$hemi -thr $thresh -bin $workdir/${sub}_Hb_ROI_ShapeOpt_thr${thresh}_bin_$hemi
		logbin="and binarized"
	else
		fslmaths $workdir/${sub}_Hb_ROI_ShapeOpt_full_$hemi -thr $thresh      $workdir/${sub}_Hb_ROI_ShapeOpt_thr${thresh}_$hemi
	fi
	if [ $? -ne 0 ] ; then exit 52 ; fi
done
echo "`date`: subject $sub Hb ShapeOpt ROIs thresholded at $thresh $logbin" | tee -a $logfile > $logdisp

# move outputs to output directory
mkdir -p $odir
mv $workdir/${sub}_Hb_ROI_ShapeOpt_*_B.nii* $odir/
if [ "$LRout" = "true" ] ; then
	mv $workdir/${sub}_Hb_ROI_ShapeOpt_*_L.nii* $odir/
	mv $workdir/${sub}_Hb_ROI_ShapeOpt_*_R.nii* $odir/
fi
echo "`date`: subject $sub Hb ShapeOpt ROI outputs saved to $odir" | tee -a $logfile > $logdisp

echo "`date`: subject $sub shape optimized Hb ROI creation complete" | tee -a $logfile > $logdisp
