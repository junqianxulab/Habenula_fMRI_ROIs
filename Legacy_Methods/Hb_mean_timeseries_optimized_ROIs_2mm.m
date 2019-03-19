% Created by Benjamin Ely.
% Version date 18 March 2019.
% Generates functional-resolution ROIs in region of Hb, with each voxel weighted by its timeseries correlation with the mean bilateral shape optimized Hb ROI timeseries.
% NB: run extract_voxelTS.sh before running this script and correct_matlab_headers.sh after

home='/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP'; % change to suit your environment
cd(home);
fprintf('Generates unthresholded mean timeseries weighted Hb ROIs at fMRI resolution.\n\n');
sublist=importdata('sublists/sublist.txt'); % list of subject IDs, one per line

% set up subject loop
% single subect version:
% for s=1
% parallel version:
parfor s=1:100
	bilatTS=importdata(sprintf('MNI_ROIs/Hb_voxelTS/%d_bilat_Hb_shapeopt_meanTS_BP_CC_FIX.txt',sublist(s)));
	leftTS=importdata(sprintf('MNI_ROIs/Hb_voxelTS/%d_left_Hb_shapeopt_voxelTS_BP_CC_FIX.txt',sublist(s))); headL=leftTS(1:3,:); leftTS=leftTS(4:4803,:);
	rightTS=importdata(sprintf('MNI_ROIs/Hb_voxelTS/%d_right_Hb_shapeopt_voxelTS_BP_CC_FIX.txt',sublist(s))); headR=rightTS(1:3,:); rightTS=rightTS(4:4803,:);
        
	% create a blank matrix corresponding to each nifti voxel
        blank=zeros(91,109,91); % adjust for different dimension sizes
        imgL=blank;
	imgR=blank;
        
	% set up a loop to go through each voxel
        for v=1:length(leftTS(1,:))
            % calculate voxel-to-mean-bilateral-timeseries correlation and set value of matrix index corresponding to that voxel
            cL=corrcoef(bilatTS,leftTS(:,v));
            imgL(headL(1,v)+1,headL(2,v)+1,headL(3,v)+1)=cL(1,2);
        end
        for v=1:length(rightTS(1,:))
            % calculate voxel-to-mean-bilateral-timeseries correlation and set value of matrix index corresponding to that voxel
            cR=corrcoef(bilatTS,rightTS(:,v));
            imgR(headR(1,v)+1,headR(2,v)+1,headR(3,v)+1)=cR(1,2);
        end

        % create the output nifti file
        niiL=make_nii(imgL,[2, 2, 2]);
	niiR=make_nii(imgR,[2, 2, 2]);
        save_nii(niiL,sprintf('%s/MNI_ROIs/Hb_meanTSopt/%d_left_meanTSopt_Hb_MNI_BP_CC_FIX.nii',home,sublist(s)));
        fprintf('Subject %d left done\n',sublist(s));
        save_nii(niiR,sprintf('%s/MNI_ROIs/Hb_meanTSopt/%d_right_meanTSopt_Hb_MNI_BP_CC_FIX.nii',home,sublist(s)));
        fprintf('Subject %d right done\n\n',sublist(s));
	
end

fprintf('Mean timeseries correlation weighting complete; now run nifti header correction script\n');
