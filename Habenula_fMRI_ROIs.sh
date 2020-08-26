#!/bin/bash
# Generates shape-optimized Hb ROIs at functional resolution in native or template space from anatomical Hb segmentations in native space.
# Created by Benjamin A. Ely
# Version date 25 Aug 2020

# functions to parse inputs
getopt1() {
	sopt="$1"
	shift 1
	for fn in $@ ; do
		if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
#			echo $fn | sed "s/^${sopt}=//"
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
			echo TRUE
			return 0
		else
			echo FALSE
			return 0
		fi
	done
}

# function to split bilateral Hb seg inputs
splitRL() {
	xlen=$(fslval $1 dim1)
	xhalf=$(echo "$xlen/2" | bc)
	fslroi $1 tmp_half 0 $xhalf 0 -1 0 -1
	fslmaths tmp_half -mul 0 tmp_zed
	fslmaths tmp_zed  -add 1 tmp_one
	fslmerge -x mask_L tmp_zed tmp_one
	fslmerge -x mask_R tmp_one tmp_zed
	fslmaths mask_L -mul $1 ${1%.nii*}_L
	fslmaths mask_R -mul $1 ${1%.nii*}_R
	imrm tmp_half tmp_zed tmp_one mask_L mask_R
}
# parse inputs
sub=`   getopt1 "--sub"    $@`
segL=`  getopt1 "--segL"   $@`
segR=`  getopt1 "--segR"   $@`
segB=`  getopt1 "--segB"   $@`
func=`  getopt1 "--func"   $@`
odir=`  getopt1 "--odir"   $@`
warp=`  getopt1 "--warp"   $@`
thresh=`getopt1 "--thresh" $@`
quiet=` getopt1 "--quiet"  $@`
###
echo sub  $sub
echo segL $segL
echo segR $segR
echo func $func
echo odir $odir

echo "`date`: $sub Hb ROI creation started"
# create working directory and dummy files
workdir="$odir/${sub}_Hb_ROI_workdir"
mkdir -p $workdir
#cd $workdir
echo workdir $workdir ###

# create regularly-spaced index at functional resolution in target space
fslmaths -dt int $func -mul 0 -Tmean -add 1 -index $workdir/${sub}_full_index_func -odt int
echo check 1 ###
# upsample index to anatomical resolution and optionally warp to native space
if [ -z $warp ] ; then
	applywarp -i $workdir/${sub}_full_index_func \
		  -r $segL \
		  -o $workdir/${sub}_full_index_anat \
	          --rel	--interp=nn # NB nearest neighbor interpolation to preserve exact index values
else
	applywarp -i $workdir/${sub}_full_index_func \
		  -r $segL \
		  -o $workdir/${sub}_full_index_anat \
		  -w $warp \
	          --rel	--interp=nn # NB nearest neighbor interpolation to preserve exact index values
fi
if [ $? -ne 0 ] ; then exit 42 ; fi
echo "`date`: $sub anatomical and functional indices created"

# add if statement to split segB
#
#
#
#

for hemi in left right ; do
		
	# mask warped index with Hb
	if [ "$hemi" = "left" ] ; then seg=$segL ; else	seg=$segR ; fi
	fslmaths $workdir/${sub}_full_index_anat -mas $seg $workdir/${sub}_${hemi}_Hb_index_anat
	if [ $? -ne 0 ] ; then exit 43 ; fi
	echo "`date`: $sub index masked with $hemi Hb segmentation"

	# determine the highest-indexed voxel in the masked region
	bins=$(fslstats $workdir/${sub}_${hemi}_Hb_index_anat -R | awk '{print $2}') 
	if [ $? -ne 0 ] ; then exit 44 ; fi
	bins=${bins%.*} 
	
	# create histogram to determine how many voxels at each indexed value survived Hb ROI masking
	fslstats $workdir/${sub}_${hemi}_Hb_index_anat -H $(( ${bins}+1 )) 0 $bins > $workdir/${sub}_histogram_${hemi}.txt
	if [ $? -ne 0 ] ; then exit 45 ; fi
	echo "`date`: $sub $hemi histogram created with $bins bins"
	
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
	# rm $workdir/${sub}_tmp1_ShapeOpt_indices_${hemi}.txt
	# rm $workdir/${sub}_tmp2_ShapeOpt_indices_${hemi}.txt
	echo "`date`: $sub $len $hemi nonzero indices identified"

	# create single-voxel masks for each voxel that survived Hb ROI masking
	mkdir -p $workdir/${sub}_Hb_ShapeOpt_voxels_${hemi}
	x=0
	for j in $(cat $workdir/${sub}_ShapeOpt_indices_${hemi}.txt | awk '{print $1}') ; do
		(( x++ ))
		# find number of anatomical voxels at current index
		weight=$(head -n $x $workdir/${sub}_ShapeOpt_indices_${hemi}.txt | tail -n 1 | awk '{print $2}')
		echo "`date`: $sub $hemi voxel $x actual occurances in masked ShapeOpt = $weight"
		# define upper and lower thresholds
		lthr=$(echo "$j - 0.1" | bc)
		uthr=$(echo "$j + 0.1" | bc)
		# find maximum possible number of anatomical voxels at each index
		max=$(fslstats $workdir/${sub}_full_index_anat -l $lthr -u $uthr -V | awk '{print $1}')
		echo "`date`: $sub $hemi voxel $x possible occurances in masked ShapeOpt = $max"
		# create mask with only current index values
		fslmaths $workdir/${sub}_${hemi}_Hb_index_anat -thr $j -uthr $j $workdir/${sub}_Hb_ShapeOpt_voxels_${hemi}/mask_anat_$x
		if [ $? -ne 0 ] ; then exit 46 ; fi
		# find average Hb probability of anatomical voxels at current index based on probabilistic segmentation
		prob=$(fslstats $seg -k $workdir/${sub}_Hb_ShapeOpt_voxels_${hemi}/mask_anat_$x -M)
		echo "`date`: $sub $hemi voxel $x mean probability in segmentation = $prob"
		# weight functional-resolution voxel for current index by average probability and fraction of possible voxels at that index included in the segmented Hb
		fslmaths $workdir/${sub}_full_index_func -thr $lthr -uthr $uthr -bin -mul $weight -div $max -mul $prob $workdir/${sub}_Hb_ShapeOpt_voxels_${hemi}/voxel_func_$x
		if [ $? -ne 0 ] ; then exit 47 ; fi
		echo "`date`: $sub $hemi voxel $x of $len complete"
	done

	# create weighted Hb ShapeOpt ROI
	fslmaths $workdir/${sub}_full_index_func -mul 0 \
		 $(echo $(for x in `ls $workdir/${sub}_Hb_ShapeOpt_voxels_${hemi}/voxel_func*.nii.gz` ; do echo -add $x ; done )) \
		 $workdir/${sub}_${hemi}_Hb_ShapeOpt_func_unscaled
	if [ $? -ne 0 ] ; then exit 48 ; fi
	echo "`date`: $sub $hemi probabilistic Hb ShapeOpt ROI created"

	# scale Hb ShapeOpt ROI weights to between 0 and 1
	min=$(fslstats $workdir/${sub}_${hemi}_Hb_ShapeOpt_func_unscaled -l 0.000001 -R | awk '{print $1}')
	max=$(fslstats $workdir/${sub}_${hemi}_Hb_ShapeOpt_func_unscaled -R | awk '{print $2}') 
	fslmaths $workdir/${sub}_${hemi}_Hb_ShapeOpt_func_unscaled \
		 -sub $min \
		 -div $(echo ${max}-${min} | bc) \
		 -thr 0 \
		 $odir/${sub}_${hemi}_Hb_ROI_ShapeOpt_prob_full
	if [ $? -ne 0 ] ; then exit 49 ; fi
	echo "`date`: $sub $hemi Hb ShapeOpt ROI probability scaled from $min = 0 to $(echo ${max}-${min} | bc) = 1"
done

# combine left/right ROIs
fslmaths $odir/${sub}_left_Hb_ROI_ShapeOpt_prob_full \
	 -add $odir/${sub}_right_Hb_ROI_ShapeOpt_prob_full \
	 $odir/${sub}_bilat_Hb_ROI_ShapeOpt_prob_full
if [ $? -ne 0 ] ; then exit 50 ; fi
echo "`date`: $sub bilateral probabilistic Hb ShapeOpt ROI created"

# threshold and binarize to create recommended shape optimized Hb fMRI ROI
fslmaths $odir/${sub}_bilat_Hb_ROI_ShapeOpt_prob_full -thr 0.25 -bin $odir/${sub}_bilat_Hb_ROI_ShapeOpt_prob_thr0.25
if [ $? -ne 0 ] ; then exit 51 ; fi
echo "`date`: $sub bilateral Hb ROI thresholded"
echo "`date`: $sub shape optimized Hb ROI creation complete"
