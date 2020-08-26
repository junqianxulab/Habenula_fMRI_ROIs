# Habenula fMRI ROIs
Generates subject-level habenula (Hb) regions of interest (ROIs) with high BOLD sensitivity for use in fMRI studies. Hb ROIs are generated at functional resolution (e.g. 2mm isotropic) based on an input Hb segmentation at anatomical resolution (e.g. 0.7mm isotropic). Optionally, output Hb ROIs can be warped to a desired template space (e.g. MNI). Note that the main Habenula_fMRI_ROIs.sh script is an updated version of the Hb_shape_optimized_ROIs_2mm.sh script (see Legacy Methods) used in (Ely BA et al. 2019, NeuroImage), modified to allow arbitrary input anatomical/functional resolutions and greater control over final ROI thresholding/size.

---
## Requirements
* FSL version 5.0.6 or later
* Unix OS (Mac OSX or Linux)

---
## Input Files

* Left and Right Hb segmentations at anatomical resolution (can be single Bilateral or separate Left/Right files)
	* We recommend automated probabilistic Hb segmentation if T1w and T2w anatomical data are available (Kim JW et al. 2016 NeuroImage; https://github.com/junqianxulab/habenula_segmentation)
	* Works best with probabilistic Hb segmentation inputs but can also accept binary Hb masks (e.g. Lawson RP et al. 2013 NeuroImage)
	* Intensity values should range from 0-1 (probabilistic) or equal 1 (binary); inputs exceeding this range will be rescaled
	* These will be treated as "native" subject space
* Example file at the target functional resolution and XYZ dimensions (i.e. NIFTI header parameters match desired output)
* [Optional] FNIRT-compatible relative warpfield files for template-to-native-space transformation
	* If using HCP pipelines, located in '${subject_directory}/MNINonLinear/xfms/standard2acpc_dc.nii.gz'

Input files should be in standard NIFTI format (.nii or .nii.gz) and can be given with or without filetype (i.e. file or file.nii.gz both work).

---
## Output Files

* Full probabilistic (weighted 0.01-1) ROIs of the Hb region at target functional resolution
	* {subject_ID}_Hb_ROI_ShapeOpt_full_{B/L/R}.nii.gz # B=bilateral, [L=left, R=right]
* Thresholded (thresh, default 0.25) and optionally binarized (bin_) shape-optimized Hb ROIs **recommended for use in fMRI studies (see Ely BA et al. 2019 NeuroImage)**
	* {subject_ID}_Hb_ROI_ShapeOpt_thr{thresh}_{bin_}{B/L/R}.nii.gz

Intermediate and log files in working directory can be deleted after ROI generation, if desired.

---
## How to Run

### Options
```
Habenula_fMRI_ROIs.sh
# Mandatory inputs:
	--sub    = subject ID
	--func   = example functional image file
	--odir   = output directory (can be absolute or relative path, will be created if not found)
	--segB   = bilateral Hb segmentation file
		OR
	--segL   = left Hb segmentation file
	--segR   = right Hb segmentation file
# Optional inputs:
	--warp   = FNIRT  warpfield, if included ROI position will be transformed accordingly
	--wdir   = working directory (created inside --odir by default)
	--thresh = final ROI threshold, default = 0.25 (works well for HCP data)
# Optional flags:
	--bin    = binarize after thresholding
	--quiet  = don't print to stdout (still logs)
	--LRout  = output separate left/right ROIs in addition to bilateral
```

### Example calls from the unix terminal:
```
# create default bilateral shape-optimized Hb ROIs in "native" space (i.e. same position as segmentation)
Habenula_fMRI_ROIs.sh \
	--sub=sub_001 \
	--segB=bilateral_Hb_segmentation.nii.gz \
	--func=example_functional.nii.gz \
	--odir=output_directory

# create bilateral + separate left/right Hb ROIs in template space
Habenula_fMRI_ROIs.sh \
	--sub=sub_001 \
	--segB=bilateral_Hb_segmentation.nii.gz \
	--func=example_functional.nii.gz \
	--odir=output_directory \
	--warp=warpfield.nii.gz \
	--LRout
```

___
# Templates
A few other potentially useful files:

* 2mm T1w MNI template brain: NIFTI header matches HCP data so can be used as --func target
	* MNI152_T1_2mm_brain.nii.gz

* Thalamus ROIs: Bilateral ROIs located anterior to and lateral to the Hb in MNI space. ROIs are non-specific but approximately correspond to dorsomedial (anterior) and centromedian (lateral) thalamic nuclei. Can be used as "control" ROIs/to regress out nearby thalammic signals during analysis. Derived by averaging Volume Optimized Hb ROIs (see Legacy Methods) from 50 HCP subjects and shifting 6mm (3 voxels) anteriorly/laterally (Ely BA et al. 2016, Human Brain Mapping).
	* Thalamus_control_ROI_anterior_to_Hb_from_Ely_HBM_2016.nii.gz
	* Thalamus_control_ROI_lateral_to_Hb_from_Ely_HBM_2016.nii.gz
	
---
# Legacy Methods
Original six methods for creating Hb fMRI ROIs evaluated in (Ely BA et al. 2019 NeuroImage). Method #3 (Hb_shape_optimized_ROIs_2mm.sh) had the highest Hb BOLD sensitivity (see above). Other methods are provided for completeness only; not recommended. Note that these scripts use input Hb segmentations created in MNI template space rather than native subject space (also not recommended) and are configured to optionally run in parallel in a LSF-based cluster computing environment.

## 1: Unoptimized Hb ROIs
Basic nearest-neighbor downsampling of binary Hb segmentation to functional resolution.
```
Hb_unoptimized_ROIs.sh
```

## 2: Volume Optimized Hb ROIs
Conservatively defined to match the estimated volume of the segmented Hb, as described in (Ely BA et al. 2016 Human Brain Mapping).
```
Hb_volume_optimized_ROIs_2mm.sh
```

## 3: Shape Optimized Hb ROIs
Liberally defined to approximate the outer boundaries/overall shape of the segmented Hb.
```
Hb_shape_optimized_ROIs_2mm.sh
```

## 4: Mean Timeseries Optimized Hb ROIs
Includes voxels most strongly correlated with the mean timeseries of the bilateral Shape Optimized Hb ROI. Volume matched to the segmented Hb, as in method 2. Requires Matlab + NifTI_tools package.
```
extract_voxelTS.sh # extract voxelwise and mean timeseries values from denoised rs-fMRI data within bilateral Hb Region ROI
Hb_mean_timeseries_optimized_ROIs.m # assign weight to each voxel based on correlation with the mean timeseries
correct_matlab_headers.sh meanTSopt # copy correct header information from an example functional file (minor bugfix)
threshold_timeseries_optimized_ROIs_2mm.sh meanTSopt # match final ROI volume to estimated volume of the segmented Hb
```

## 5: Pairwise Timeseries Optimized Hb ROIs
Includes voxels with strongest pairwise correlations within the Shape Optimized Hb ROI. Volume matched to the segmented Hb, as in method 2. Requires Matlab + NifTI_tools package.
```
extract_voxelTS.sh # (if not run already) extract voxelwise and mean timeseries values from denoised rs-fMRI data within bilateral Hb Region ROI
Hb_pairwise_timeseries_optimized_ROIs_2mm.m # calculate timeseries correlation of each voxel with each other voxel and assign weight based on strongest correlation
correct_matlab_headers.sh pairTSopt # copy correct header information from an example functional file (minor bugfix)
threshold_timeseries_optimized_ROIs_2mm.sh pairTSopt # match final ROI volume to estimated volume of the segmented Hb
```

## 6: Hb Template ROI
Generic ROI created by averaging Hb segmentations from 68 HCP subjects then downsampling to functional resolution, with volume matched to the averaged segmented Hb volume, similar to method 2.
```
Hb_template_ROI_2mm_MNI.nii.gz
```

---
# References:
## If using these scripts, please cite:
Ely BA et al. 'Detailed mapping of human habenula resting-state functional connectivity', NeuroImage 2019 200:621-634, https://pubmed.ncbi.nlm.nih.gov/31252057

## Related work by our group and others:
Ely BA et al. 'Resting-state functional connectivity of the human habenula in healthy individuals: associations with subclinical depression', Human Brain Mapping 2016 37:2369-84, https://www.ncbi.nlm.nih.gov/pubmed/26991474 
Kim JW et al. 'Human habenula segmentation using myelin content', NeuroImage 2016 130:145-56, http://www.ncbi.nlm.nih.gov/pubmed/26826517
Kim JW et al. 'Reproducibility of myelin content-based human habenula segmentation at 3 Tesla', Human Brain Mapping 2018 39:3058-71, https://pubmed.ncbi.nlm.nih.gov/29582505
Lawson RP et al. 'Defining the habenula in human neuroimaging studies', NeuroImage 2013 64:722-7, https://www.ncbi.nlm.nih.gov/pubmed/22986224 
