#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning video QC script for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
fi

# move to study folder to loop over patients - python function defined per patient
cd "$data_root"/PROTECTED/"$study"/processed
# will do one loop for open and another for psychs
echo "Processing new open interviews"
for p in *; do
	# first check that it is truly a patient ID, that has an extracted frames folder for the open interviews
	if [[ ! -d $p/interviews/open/video_frames ]]; then
		continue
	fi
	cd "$p"/interviews/open

	# then check that there is something in that folder before continuing
	if [ -z "$(ls -A video_frames)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi
	cd video_frames

	echo "On patient ${p}"
	
	# now can run main video QC script on this patient
	python "$func_root"/interview_video_qc.py "open" "$data_root" "$study" "$p"

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done

echo "Processing new psychs interviews"
for p in *; do
	# first check that it is truly a patient ID, that has an extracted frames folder for the psychs interviews
	if [[ ! -d $p/interviews/psychs/video_frames ]]; then
		continue
	fi
	cd "$p"/interviews/psychs

	# then check that there is something in that folder before continuing
	if [ -z "$(ls -A video_frames)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi
	cd video_frames

	echo "On patient ${p}"
	
	# now can run main video QC script on this patient
	python "$func_root"/interview_video_qc.py "psychs" "$data_root" "$study" "$p"

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done