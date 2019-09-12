# Habenula fMRI ROIs
Generates subject-level habenula (Hb) regions of interest (ROIs) with high BOLD sensitivity for use in fMRI studies. Hb ROIs are generated at functional resolution (e.g. 2mm isotropic) based on an input Hb segmentation at anatomical resolution (e.g. 0.7mm isotropic). Optionally, output Hb ROIs can be warped to a desired template space (e.g. MNI). Note that the main Habenula_fMRI_ROIs.sh script is an updated version of the Hb_shape_optimized_ROIs_2mm.sh script (see Legacy Methods) used in (Ely BA et al. 2019 NeuroImage), modified to allow arbitrary input anatomical/functional resolutions and greater control over final ROI thresholding/size.

---
## Requirements
* FSL version 5.0.6 or later
* Unix OS (Mac OSX or Linux)

---
## Input Files
* Left Hb segmentation at anatomical resolution in native subject space
* Right Hb segmentation at anatomical resolution in native subject space
	* We recommend automated probabilistic Hb segmentation if T1w and T2w anatomical data are available (Kim JW et al. 2016 NeuroImage; https://github.com/junqianxulab/habenula_segmentation)
	* Should also work for manually-defined binary Hb masks (e.g. Lawson RP et al. 2013 NeuroImage; https://github.com/junqianxulab/habenula_segmentation_lawson)
* Example file at the target functional resolution and XYZ dimensions (i.e. NIFTI header parameters match desired output)
* (Optional) FNIRT-compatible relative warpfield for transforming from template to native space 
	* If using HCP pipelines, located in '${subject_directory}/MNINonLinear/xfms/standard2acpc_dc.nii.gz'

Note that input files should be in standard NIFTI1 format (.nii or .nii.gz). Intensity values for the segmented Hb should range from 0-1 if probabilistic or equal 1 if binary.

---
## Outputs
* Shape-optimized Hb ROI created by thresholding (25th percentile) and binarizing the probabilistic bilateral Hb region ROI. Recommended Hb ROI for use in fMRI studies (Ely BA et al. 2019 NeuroImage).
	* ${subject_ID}_bilat_shape_optimized_Hb_ROI.nii.gz
* Probabilistic left, right, and bilateral Hb region ROIs at target functional resolution (and in template space if warpfield supplied).
	* ${subject_ID}_left_Hb_region_full_prob.nii.gz
	* ${subject_ID}_right_Hb_region_full_prob.nii.gz
	* ${subject_ID}_bilat_Hb_region_full_prob.nii.gz
* Working directory containing various intermediate files; can be deleted after ROI generation, if desired.
	* ${subject_ID}_Hb_ROI_workdir/

---
## How to Run

### From the unix terminal:
```
Habenula_fMRI_ROIs.sh --sub=subject_ID --segL=segmented_Hb_left.nii.gz --segR=segmented_Hb_right.nii.gz --func=example_functional.nii.gz --odir=output_directory [--warp=warpfield.nii.gz] 
```

#### Options
```
Habenula_fMRI_ROIs.sh
	--sub  = subject ID
	--segL = left Hb segmentation file
	--segR = right Hb segmentation file
	--func = example functional image file
	--odir = path to output directory
       [--warp = optional warpfield, if included Hb ROI position will be transformed accordingly]
```

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

[1] Ely BA et al., 'Resting-state functional connectivity of the human habenula in healthy individuals: associations with subclinical depression', 2016, Human Brain Mapping, 37:2369-84, https://www.ncbi.nlm.nih.gov/pubmed/26991474 

[2] Ely BA et al., 'Detailed mapping of human habenula resting-state functional connectivity', 2019, NeuroImage, 200:621-34 https://www.ncbi.nlm.nih.gov/pubmed/31252057

[3] Kim JW et al., 'Human habenula segmentation using myelin content', 2016, NeuroImage, 130:145-56, http://www.ncbi.nlm.nih.gov/pubmed/26826517

[4] Lawson RP et al., 'Defining the habenula in human neuroimaging studies', 2013, NeuroImage, 64:722-7, https://www.ncbi.nlm.nih.gov/pubmed/22986224 
