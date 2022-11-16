#! /bin/bash

##Input taken: subject_ID, Step#, roi, run##

#Step 1: disable wireless internet, set MURFI_SUBJECTS_DIR, and NAMEcd
#Step 2: receive 2 volume scan
#Step 3: create masks
#Step 4: run murfi for realtime

subj=$1
ses=$2
run=$3
step=$4

subj_dir=../subjects/$subj
cwd=$(pwd)
absolute_path=$(dirname $cwd)
subj_dir_absolute="${absolute_path}/subjects/$subj"
#subject_data_dir=../data/${subj}/ses-localizer/func/
fsl_scripts=../scripts/fsl_scripts
if [ ${step} = setup ]
then
    clear
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "+ Wellcome to MURFI real-time Neurofeedback"
    echo "+ running " ${step}
    export MURFI_SUBJECTS_DIR=../subjects/
    export MURFI_SUBJECT_NAME=$subj
    echo "+ subject ID: "$MURFI_SUBJECT_NAME
    echo "+ working dir: $MURFI_SUBJECTS_DIR"
    #echo "disabling wireless internet"
    #ifdown wlan0
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "checking the presence of scanner and stim computer"
    ping -c 3 192.168.2.1
    ping -c 3 192.168.2.6
    echo "make sure Wi-Fi is off"
    echo "make sure you are Wired Connected to rt-fMRI"
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
fi  
  
if [ ${step} = 2vol ]
then
    clear
    echo "ready to receive 2 volume scan"
    singularity exec /home/auerbachlinux/singularity-images/murfi2.sif murfi -f $subj_dir/xml/2vol.xml
fi


# if [ ${step} = nf ]
# then
# clear
#     echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
#     echo "ready to receive stg feedback scan"
#     singularity exec /home/auerbachlinux/singularity-images/murfi2.sif murfi -f $subj_dir/xml/$subj_$run.xml
# fi

if  [ ${step} = feedback ]
then
clear
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "ready to receive rtdmn feedback scan"
    singularity exec /home/auerbachlinux/singularity-images/murfi2.sif murfi -f $subj_dir/xml/rtdmn.xml
fi


if  [ ${step} = resting_state ]
then
clear
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "ready to receive resting state scan"
    singularity exec /home/auerbachlinux/singularity-images/murfi2.sif murfi -f $subj_dir/xml/rest.xml
fi



if  [ ${step} = extract_rs_networks ]
then
clear
    echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "+ compiling resting state run into analysis folder"
    #cp $subj_dir/img/img-00002-00002.nii  $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.nii
    #yes n | gzip $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.nii
    
    # get all volumes of resting data (no matter how many) merged into 1 .nii.gz file
    # NOTE: the -00002 extensipn will likely need to be adjusted depending on where this scan falls in the protocol
    fslmerge -tr $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.nii.gz $subj_dir/img/img-00002* 1.2
    chmod 777 $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.nii.gz 

    # figure out how many volumes of resting state data there were to be used in ICA
    restvolumes=$(fslnvols $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.nii.gz)

    echo "+ computing resting state networks this will take about 25 minutes"
    echo "+ started at: $(date)"
    
    # update FEAT template with paths and # of volumes of resting state run
    cp $fsl_scripts/rest_template.fsf $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.fsf
    DATA_path=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.nii.gz
    OUTPUT_dir=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'
    sed -i "s#DATA#$subj_dir_absolute/rest/${subj}_${ses}_task-rest_${run}_bold.nii.gz#g" $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.fsf
    sed -i "s#OUTPUT#$OUTPUT_dir#g" $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.fsf

    # update fsf to match number of rest volumes
    sed -i "s/set fmri(npts) 248/set fmri(npts) ${restvolumes}/g" $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.fsf
    feat $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.fsf
fi



if [ ${step} = process_roi_masks ]
then
clear
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    echo "+ Generating DMN & CEN Masks "
    echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    touch $subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/Yeo_rsn_correl.txt
correlfile=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/Yeo_rsn_correl.txt

infile=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/melodic_IC.nii.gz 

infile_2mm=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/melodic_IC_2mm.nii.gz

examplefunc=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/reg/example_func.nii.gz

standard=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/reg/standard.nii.gz

example_func2standard_mat=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/reg/example_func2standard.mat

standard2example_func_mat=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/reg/standard2example_func.mat
template_networks='template_networks.nii.gz'

#yeo7networks=../scripts/FSL_7networks.nii
#yeo7networks2example_func=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/reg/yeo7networks2example_func.nii.gz

template_dmn='DMNa_brainmaskero2.nii'
template_cen='CENa_brainmaskero2.nii'
fslmerge -tr ${template_networks} ${template_dmn} ${template_cen} 1

template2example_func=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/reg/template_networks2example_func.nii.gz

flirt -in ${template_networks} -ref ${examplefunc} -out ${template2example_func} -init ${standard2example_func_mat} -applyxfm


split_outfile=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/melodic_IC_

# SHOULD we correlate with just DMN & CEN, rather than all yeo networks?
fslcc --noabs -p 3 -t 0.05 ${infile} ${template2example_func} >>${correlfile}
fslsplit ${infile} ${split_outfile}

python rsn_get.py ${subj} ${ses} ${run}


dmn_uthresh=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/dmn_uthresh.nii.gz
cen_uthresh=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/cen_uthresh.nii.gz

#dmn_thresh=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/dmn_thresh.txt
#cen_thresh=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/cen_thresh.txt

dmn_mni_thresh=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/dmn_mni_thresh.nii.gz
cen_mni_thresh=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/cen_mni_thresh.nii.gz
dmn_mni_uthresh=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/dmn_mni_uthresh.nii.gz
cen_mni_uthresh=$subj_dir/rest/$subj'_'$ses'_task-rest_'$run'_bold'.ica/filtered_func_data.ica/cen_mni_uthresh.nii.gz


#ERODE
#top X voxels?


# UPDATE Pipeline
# pull in eroded DMN / CEN masks
# zero out any voxels in the unthresholded personalized networks that aren't in the masks
# take the top N (hardcoded) voxels from that 

num_voxels_desired=1500

# register non-thresholded masks to MNI space
flirt -in  ${dmn_uthresh} -ref ${standard} -out ${dmn_mni_uthresh} -init ${example_func2standard_mat} -applyxfm
flirt -in  ${cen_uthresh} -ref ${standard} -out ${cen_mni_uthresh} -init ${example_func2standard_mat} -applyxfm


# zero out voxels not included in the template mask
fslmaths ${dmn_mni_uthresh} -mul ${template_dmn} ${dmn_mni_uthresh}
fslmaths ${cen_mni_uthresh} -mul ${template_cen} ${cen_mni_uthresh}


# get number of non-zero voxels in masks, calculate percentile of voxels desired
voxels_in_dmn=$(fslstats ${dmn_mni_uthresh} -V | awk '{print $1}')
percentile_dmn=$(python -c "print(100*(1-${num_voxels_desired}/${voxels_in_dmn}))")
voxels_in_cen=$(fslstats ${cen_mni_uthresh} -V | awk '{print $1}')
percentile_cen=$(python -c "print(100*(1-${num_voxels_desired}/${voxels_in_cen}))")


# get threshold based on percentile
dmn_thresh_value=$(fslstats ${dmn_mni_uthresh} -P ${percentile_dmn})
cen_thresh_value=$(fslstats ${cen_mni_uthresh} -P ${percentile_cen})

# threshold masks in MNI space
fslmaths ${dmn_mni_uthresh} -thr ${dmn_thresh_value} -bin ${dmn_mni_thresh} -odt short
fslmaths ${cen_mni_uthresh} -thr ${cen_thresh_value} -bin ${cen_mni_thresh} -odt short


echo "Number of voxels in dmn mask: $(fslstats ${dmn_mni_thresh} -V)"
echo "Number of voxels in cen mask: $(fslstats ${cen_mni_thresh} -V)"

# copy masks to mask directory
cp ${dmn_mni_thresh} ${subj_dir}/mask/mni/dmn_mni.nii.gz
cp ${cen_mni_thresh} ${subj_dir}/mask/mni/cen_mni.nii.gz


# Display masks with FSLEYES
fsleyes  mean_brain.nii.gz ${dmn_mni_thresh} -cm blue ${cen_mni_thresh} -cm red


fi

# #Here you can change the size of the DMN/CEN mask
# #thresh=500
# threshvalue=99.7
# #while [$thresh>=100]
# #do
# #threshvalue=$(($threshvalue +0.01)) | bc
# fslstats ${dmn_uthresh} -P $threshvalue >${dmn_thresh}
# thresh="$(awk '{print $1}' ${dmn_thresh})"
# fslmaths ${dmn_uthresh} -thr ${thresh} -bin ${dmn_mni_thresh} -odt short
# flirt -in  ${dmn_mni_thresh} -ref ${standard} -out ${dmn_mni_thresh} -init ${example_func2standard_mat} -applyxfm
# fslmaths ${dmn_mni_thresh} -mul ../scripts/FSL_7networks_DMN.nii.gz ${dmn_mni_thresh}

# fslstats ${cen_uthresh} -P $threshvalue >${cen_thresh}
# thresh="$(awk '{print $1}' ${cen_thresh})"
# fslmaths ${cen_uthresh} -thr ${thresh} -bin ${cen_mni_thresh} -odt short
# flirt -in  ${cen_mni_thresh} -ref ${standard} -out ${cen_mni_thresh} -init ${example_func2standard_mat} -applyxfm
# fslmaths ${cen_mni_thresh} -mul ../scripts/FSL_7networks_CEN.nii.gz ${cen_mni_thresh}

# # fslstats ${smc_uthresh} -P $threshvalue >${smc_thresh}
# # thresh="$(awk '{print $1}' ${smc_thresh})"
# # fslmaths ${smc_uthresh} -thr ${thresh} -bin ${smc_mni_thresh} -odt short
# # flirt -in  ${smc_mni_thresh} -ref ${standard} -out ${smc_mni_thresh} -init ${example_func2standard_mat} -applyxfm
# # fslmaths ${smc_mni_thresh} -mul ../scripts/FSL_7networks_SMC.nii.gz ${smc_mni_thresh}

# cp ${dmn_mni_thresh} ${subj_dir}/mask/mni/dmn_mni.nii.gz
# cp ${cen_mni_thresh} ${subj_dir}/mask/mni/cen_mni.nii.gz
# cp ${smc_mni_thresh} ${subj_dir}/mask/mni/smc_mni.nii.gz

# fsleyes  mean_brain.nii.gz ${subj_dir}/mask/mni/dmn_mni.nii.gz -cm blue ${subj_dir}/mask/mni/cen_mni.nii.gz -cm red ${subj_dir}/mask/mni/smc_mni.nii.gz -cm green

# fi
