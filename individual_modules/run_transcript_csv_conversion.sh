#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning transcript CSV conversion script for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
fi

# move to study folder to loop over patients
cd "$data_root"/GENERAL/"$study"/processed
# will do one loop for open and another for psychs
echo "Processing new open interview transcripts"
for p in *; do # loop over all patients in the specified study folder on PHOENIX
	# first check that it is truly a patient ID, that has a transcripts folder for the open interviews
	if [[ ! -d $p/interviews/open/transcripts ]]; then
		continue
	fi
	cd "$p"/interviews/open/transcripts

	# make csv subfolder if this is the first transcript conversion for this patient
	if [[ ! -d csv ]]; then 
		mkdir csv 
	fi

	# setup tracking information
	pt_has_new=false # only mention patients in log that had new transcripts to process, tracked with this Boolean
	encountered_non_ascii=false # similarly add a print to log at end if ever encountered non-ASCII characters
	# (latter just for main pipeline, as details of missed transcripts will only go in email alert in that case)

	# all text files on top level should be approved redacted transcripts, loop through them
	for file in *.txt; do	
		# initial file checks
		[[ ! -e "${file}" ]] && continue # avoid file not found error from empty folder	
		name=$(echo "$file" | awk -F '.' '{print $1}')
		[[ -e csv/"${name}".csv ]] && continue # if already have a formatted copy skip
		pt_has_new=true # so if get here means there is some new file to convert
		
		# begin conversion for this applicable file
		# ensure transcript is in ASCII encoding (sometimes they returned UTF-8, usually just a few offending characters that need to be fixed)
		typecheck=$(file -n "$file" | grep ASCII | wc -l)
		if [[ $typecheck == 0 ]]; then
			encountered_non_ascii=true

			# if it's not ASCII need to skip the file, setup error message
			# for now will need to manually fix any offending txt files and then rerun the conversion (and later pipeline steps) for those
			# hopefully in future will have a way to deal with it fully automatically
			echo "" # also add spacing around it because the grep output could end up being long
			echo "Found transcript that is not ASCII encoded, skipping for now. Please address the following portions of ${file}:"
			grep_out=$(grep -P '[^\x00-\x7f]' "$file")
			echo "$grep_out"
			echo ""
			if [[ ! -z "${repo_root}" ]]; then
				# if this module was called via the main pipeline, should add this info to the end of the email alert file (after a blank line) as well
				echo "" >> "$repo_root"/transcript_lab_email_body.txt
				echo "Possible error during post processing of new redacted transcripts!" >> "$repo_root"/transcript_lab_email_body.txt
				echo "${file} is not ASCII encoded, so is not currently able to be processed. Please remove offending characters and then rerun processing steps on this transcript. The following command can be executed to identify the problematic parts:" >> "$repo_root"/transcript_lab_email_body.txt
				echo "​grep -P '[^\x00-\x7f]' ${data_root}/GENERAL/${study}/processed/${p}/interviews/open/transcripts/${file}" >> "$repo_root"/transcript_lab_email_body.txt
				# not actually including the output here so that email won't ever accidentally include PII (although transcripts in GENERAL should be redacted already!)
			fi

			continue 
		fi

		# substitute tabs with single space for easier parsing (returned by transcribeme see a mix!)
		# this file will be kept only temporarily
		sed 's/\t/ /g' "$file" > "$name"_noTABS.txt

		# prep CSV with column headers
		# (no reason to have DPDash formatting for a transcript CSV, so I choose these columns)
		# (some of them are just for ease of future concat/merge operations)
		echo "study,patient,filename,subject,timefromstart,text" > csv/"$name".csv

		# check subject number format, as they've used a few different delimiters in the past
		# (this does assume they are consistent with one format throughout a single file though)
		subcheck=$(cat "$file" | grep S1: | wc -l) # subject 1 is guaranteed to appear at least once as it is the initial ID they assign 

		# read in transcript line by line to convert to CSV rows
		while IFS='' read -r line || [[ -n "$line" ]]; do
			if [[ $subcheck == 0 ]]; then # subject ID always comes first, is sometimes followed by a colon
				sub=$(echo "$line" | awk -F ' ' '{print $1}') 
			else
				sub=$(echo "$line" | awk -F ': ' '{print $1}')
			fi
			time=$(echo "$line" | awk -F ' ' '{print $2}') # timestamp always comes second
			text=$(echo "$line" | awk -F '[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9] ' '{print $2}') # get text based on what comes after timestamp in expected format (MM:SS.milliseconds)
			# the above still works fine if hours are also provided, it just hinges on full minute digits and millisecond resolution being provided throughout the transcript
			if [[ -z "$text" ]]; then
				# text variable could end up empty because ms resolution not provided, so first try a different way of splitting, looking for space after the SS part of the timestamp
				text=$(echo "$line" | awk -F '[0-9][0-9]:[0-9][0-9] ' '{print $2}')
				if [[ -z "$text" ]]; then
					# if text is still empty safe to assume this is an empty line, which do occur - skip it!
					continue
				fi
			fi
			text=$(echo "$text" | tr -d '"') # remove extra characters at end of each sentence
			text=$(echo "$text" | tr -d '\r') # remove extra characters at end of each sentence
			echo "${study},${p},${name},${sub},${time},\"${text}\"" >> csv/"$name".csv # add the line to CSV
		done < "$name"_noTABS.txt

		# remove the temporary file
		rm "$name"_noTABS.txt
	done

	if [[ "$pt_has_new" = true ]]; then
		echo "Done converting new redacted open transcripts to CSV for ${p}"
	fi

	cd "$data_root"/GENERAL/"$study"/processed # at end of patient reset to root study dir for next loop
done

# repeat full loop for psychs interviews
cd "$data_root"/GENERAL/"$study"/processed
echo "Processing new psychs interview transcripts"
for p in *; do # loop over all patients in the specified study folder on PHOENIX
	# first check that it is truly a patient ID, that has a transcripts folder for the psychs interviews
	if [[ ! -d $p/interviews/psychs/transcripts ]]; then
		continue
	fi
	cd "$p"/interviews/psychs/transcripts

	# make csv subfolder if this is the first transcript conversion for this patient
	if [[ ! -d csv ]]; then 
		mkdir csv 
	fi

	# setup tracking information
	pt_has_new=false # only mention patients in log that had new transcripts to process, tracked with this Boolean
	encountered_non_ascii=false # similarly add a print to log at end if ever encountered non-ASCII characters
	# (latter just for main pipeline, as details of missed transcripts will only go in email alert in that case)

	# all text files on top level should be approved redacted transcripts, loop through them
	for file in *.txt; do	
		# initial file checks
		[[ ! -e "${file}" ]] && continue # avoid file not found error from empty folder	
		name=$(echo "$file" | awk -F '.' '{print $1}')
		[[ -e csv/"${name}".csv ]] && continue # if already have a formatted copy skip
		pt_has_new=true # so if get here means there is some new file to convert
		
		# begin conversion for this applicable file
		# ensure transcript is in ASCII encoding (sometimes they returned UTF-8, usually just a few offending characters that need to be fixed)
		typecheck=$(file -n "$file" | grep ASCII | wc -l)
		if [[ $typecheck == 0 ]]; then
			encountered_non_ascii=true

			# if it's not ASCII need to skip the file, setup error message
			# for now will need to manually fix any offending txt files and then rerun the conversion (and later pipeline steps) for those
			# hopefully in future will have a way to deal with it fully automatically
			echo "" # also add spacing around it because the grep output could end up being long
			echo "Found transcript that is not ASCII encoded, skipping for now. Please address the following portions of ${file}:"
			grep_out=$(grep -P '[^\x00-\x7f]' "$file")
			echo "$grep_out"
			echo ""
			if [[ ! -z "${repo_root}" ]]; then
				# if this module was called via the main pipeline, should add this info to the end of the email alert file (after a blank line) as well
				echo "" >> "$repo_root"/transcript_lab_email_body.txt
				echo "Possible error during post processing of new redacted transcripts!" >> "$repo_root"/transcript_lab_email_body.txt
				echo "${file} is not ASCII encoded, so is not currently able to be processed. Please remove offending characters and then rerun processing steps on this transcript. The following command can be executed to identify the problematic parts:" >> "$repo_root"/transcript_lab_email_body.txt
				echo "​grep -P '[^\x00-\x7f]' ${data_root}/GENERAL/${study}/processed/${p}/interviews/psychs/transcripts/${file}" >> "$repo_root"/transcript_lab_email_body.txt
				# not actually including the output here so that email won't ever accidentally include PII (although transcripts in GENERAL should be redacted already!)
			fi

			continue 
		fi

		# prep CSV with column headers
		# (no reason to have DPDash formatting for a transcript CSV, so I choose these columns)
		# (some of them are just for ease of future concat/merge operations)
		echo "study,patient,filename,subject,timefromstart,text" > csv/"$name".csv

		# check subject number format, as they've used a few different delimiters in the past
		# (this does assume they are consistent with one format throughout a single file though)
		subcheck=$(cat "$file" | grep S1: | wc -l) # subject 1 is guaranteed to appear at least once as it is the initial ID they assign 

		# read in transcript line by line to convert to CSV rows
		while IFS='' read -r line || [[ -n "$line" ]]; do
			if [[ $subcheck == 0 ]]; then # subject ID always comes first, is sometimes followed by a colon
				sub=$(echo "$line" | awk -F ' ' '{print $1}') 
			else
				sub=$(echo "$line" | awk -F ': ' '{print $1}')
			fi
			time=$(echo "$line" | awk -F ' ' '{print $2}') # timestamp always comes second
			text=$(echo "$line" | awk -F '[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9] ' '{print $2}') # get text based on what comes after timestamp in expected format (MM:SS.milliseconds)
			# the above still works fine if hours are also provided, it just hinges on full minute digits and millisecond resolution being provided throughout the transcript
			if [[ -z "$text" ]]; then
				# text variable could end up empty because ms resolution not provided, so first try a different way of splitting, looking for space after the SS part of the timestamp
				text=$(echo "$line" | awk -F '[0-9][0-9]:[0-9][0-9] ' '{print $2}')
				if [[ -z "$text" ]]; then
					# if text is still empty safe to assume this is an empty line, which do occur - skip it!
					continue
				fi
			fi
			text=$(echo "$text" | tr -d '"') # remove extra characters at end of each sentence
			text=$(echo "$text" | tr -d '\r') # remove extra characters at end of each sentence
			echo "${study},${p},${name},${sub},${time},\"${text}\"" >> csv/"$name".csv # add the line to CSV
		done < "$file"
	done

	if [[ "$pt_has_new" = true ]]; then
		echo "Done converting new redacted psychs transcripts to CSV for ${p}"
	fi

	cd "$data_root"/GENERAL/"$study"/processed # at end of patient reset to root study dir for next loop
done