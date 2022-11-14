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

	for subfolder in *; do
		# delete any empty extracted frames folders
		if [ -z "$(ls -A ${subfolder})" ]; then
			rm -rf "$subfolder"
		fi
	done

	# confirm once more the video frames folder for this ID isn't empty
	cd ..
	if [ -z "$(ls -A video_frames)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi
	cd video_frames

	# now safe to start
	echo "On patient ${p}"
	
	# now can run main video QC script on this patient
	python "$func_root"/interview_video_qc.py "open" "$data_root" "$study" "$p"

	# check if video qc crashed and handle that accordingly by treating the interviews as unprocessed and logging/emailing warning about the subject ID
	if [ $? = 1 ]; then 
		echo "Video QC script failed for subject ${p} open interviews today, so they skip being processed - please check manually"
	
		# if calling from pipeline make a note it crashed!
		if [[ -e "$repo_root"/video_lab_email_body.txt ]]; then 
			echo "Note that video QC crashed for new open interviews from subject ${p}. They have been skipped for now, may require manual investigation." >> "$repo_root"/video_lab_email_body.txt
			echo "" >> "$repo_root"/video_lab_email_body.txt
		fi	

		# remove all the new interview frame folders then
		for folder in *; do
			# PyFeatOutputs should only not exist for those checked today
			if [[ ! -d ${folder}/PyFeatOutputs ]]; then
				rm -rf "$folder"
			fi
		done

		# back out of folder before continuing to next patient
		cd "$data_root"/PROTECTED/"$study"/processed
		continue
	fi

	# if video qc didn't crash need to confirm each individual folder was processed - mark as completed if so, delete if not
	# will also log/email for failure case, compile success list else
	for folder in *; do
		# first skip over any previously processed ones
		if [[ -d ${folder}/PyFeatOutputs ]]; then
			continue
		fi

		# next confirm the processing did not fail for this folder
		if [[ ! -d ${folder}/PyFeatOutputsTemp ]]; then
			echo "Frame image extraction failed for open ${folder} - skipping for now, please revisit"
			# also including in email if calling from pipeline
			if [[ -e "$repo_root"/video_lab_email_body.txt ]]; then 
				echo "Note that the raw open video file ${name} for subject ${p} failed to have any frame still images extracted and has been skipped by processing for now" >> "$repo_root"/video_lab_email_body.txt
				echo "" >> "$repo_root"/video_lab_email_body.txt
			fi	

			# finally just delete the folder so it can try again next time (perhaps after site edits or code changes or something)
			rm -rf "$folder"
		else
			# in this case we are all good! mark as done via folder name change, also log to list for eventual email
			mv "$folder"/PyFeatOutputsTemp "$folder"/PyFeatOutputs
			# also including in email if calling from pipeline, added to separate txt for now so it will come after warnings
			# make sure use future rename formatting!
			if [[ -e "$repo_root"/video_lab_email_body.txt ]]; then 
				cat "$folder"/"$folder".txt >> "$repo_root"/video_temp_process_list.txt
				# add new line between multiple interviews
				echo "" >> "$repo_root"/video_temp_process_list.txt
			fi	
		fi
	done

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

	for subfolder in *; do
		# delete any empty extracted frames folders
		if [ -z "$(ls -A ${subfolder})" ]; then
			rm -rf "$subfolder"
		fi
	done

	# confirm once more the video frames folder for this ID isn't empty
	cd ..
	if [ -z "$(ls -A video_frames)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi
	cd video_frames

	# now safe to start
	echo "On patient ${p}"
	
	# now can run main video QC script on this patient
	python "$func_root"/interview_video_qc.py "psychs" "$data_root" "$study" "$p"

	# check if video qc crashed and handle that accordingly by treating the interviews as unprocessed and logging/emailing warning about the subject ID
	if [ $? = 1 ]; then 
		echo "Video QC script failed for subject ${p} psychs interviews today, so they skip being processed - please check manually"
	
		# if calling from pipeline make a note it crashed!
		if [[ -e "$repo_root"/video_lab_email_body.txt ]]; then 
			echo "Note that video QC crashed for new psychs interviews from subject ${p}. They have been skipped for now, may require manual investigation." >> "$repo_root"/video_lab_email_body.txt
			echo "" >> "$repo_root"/video_lab_email_body.txt
		fi	

		# remove all the new interview frame folders then
		for folder in *; do
			# PyFeatOutputs should only not exist for those checked today
			if [[ ! -d ${folder}/PyFeatOutputs ]]; then
				rm -rf "$folder"
			fi
		done

		# back out of folder before continuing to next patient
		cd "$data_root"/PROTECTED/"$study"/processed
		continue
	fi

	# if video qc didn't crash need to confirm each individual folder was processed - mark as completed if so, delete if not
	# will also log/email for failure case, compile success list else
	for folder in *; do
		# first skip over any previously processed ones
		if [[ -d ${folder}/PyFeatOutputs ]]; then
			continue
		fi

		# next confirm the processing did not fail for this folder
		if [[ ! -d ${folder}/PyFeatOutputsTemp ]]; then
			echo "Frame image extraction failed for psychs ${folder} - skipping for now, please revisit"
			# also including in email if calling from pipeline
			if [[ -e "$repo_root"/video_lab_email_body.txt ]]; then 
				echo "Note that the raw psychs video file ${name} for subject ${p} failed to have any frame still images extracted and has been skipped by processing for now" >> "$repo_root"/video_lab_email_body.txt
				echo "" >> "$repo_root"/video_lab_email_body.txt
			fi	

			# finally just delete the folder so it can try again next time (perhaps after site edits or code changes or something)
			rm -rf "$folder"
		else
			# in this case we are all good! mark as done via folder name change, also log to list for eventual email
			mv "$folder"/PyFeatOutputsTemp "$folder"/PyFeatOutputs
			# also including in email if calling from pipeline, added to separate txt for now so it will come after warnings
			# make sure use future rename formatting!
			if [[ -e "$repo_root"/video_lab_email_body.txt ]]; then 
				cat "$folder"/"$folder".txt >> "$repo_root"/video_temp_process_list.txt
				# add new line between multiple interviews
				echo "" >> "$repo_root"/video_temp_process_list.txt
			fi	
		fi
	done

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done