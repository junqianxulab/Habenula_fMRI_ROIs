% Ely, 22 Aug 2017. Based on MNI_biopt.m script, modified to use fully-denoised fMRI inputs

% NB: run par_MNI_extract_voxelwise_TS.sh before running this script and correct_biopt_headers.sh after

home='/sc/orga/projects/sterne04a/hb_rFMRI_7T_3T_HCP';
cd(home);
fprintf('Generates fMRI ROIs from Bandpass + CompCor + ICAFIX denoised 3T data.\n\n');
sublist=importdata('sublists/sublist.txt');
% set up subject loop
% parfor s=1:68
% parfor s=1:12
%parfor s=13:68
for s=6
	bilatTS=importdata(sprintf('MNI_ROIs/Hb_TSregion/%d_bilat_Hb_region_meanTS_BP_CC_FIX.txt',sublist(s)));
	leftTS=importdata(sprintf('MNI_ROIs/Hb_TSregion/%d_left_Hb_region_voxelTS_BP_CC_FIX.txt',sublist(s))); headL=leftTS(1:3,:); leftTS=leftTS(4:4803,:);
	rightTS=importdata(sprintf('MNI_ROIs/Hb_TSregion/%d_right_Hb_region_voxelTS_BP_CC_FIX.txt',sublist(s))); headR=rightTS(1:3,:); rightTS=rightTS(4:4803,:);
        
	% create a blank matrix corresponding to each nifti voxel
        blank=zeros(91,109,91);
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
        save_nii(niiL,sprintf('%s/MNI_ROIs/Hb_biopt/%d_left_biopt_Hb_MNI_BP_CC_FIX.nii',home,sublist(s)));
        fprintf('Subject %d left done\n',sublist(s));
        save_nii(niiR,sprintf('%s/MNI_ROIs/Hb_biopt/%d_right_biopt_Hb_MNI_BP_CC_FIX.nii',home,sublist(s)));
        fprintf('Subject %d right done\n\n',sublist(s));
	
end

fprintf('Script complete; now run nifti header correction script\n');
