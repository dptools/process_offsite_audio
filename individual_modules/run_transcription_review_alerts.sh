#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

# this particular script it doesn't make any sense to call from outside the pipeline
if [[ -z "${repo_root}" ]]; then
	exit
fi

# move to study's processed folder to loop over patients
cd "$data_root"/PROTECTED/"$study"/processed
for p in *; do
	# first check that it is truly a patient ID that has interview data
	if [[ ! -d $p/interviews ]]; then
		continue
	fi
	cd "$p"/interviews

	# now check open and then psychs for transcripts of interest - in prescreening means they were sent for the sites to review
	if [[ -d open/transcripts/prescreening ]];
		cd open/transcripts/prescreening
		for file in *.txt; do
			if [[ ! -e $file ]]; then # make sure don't get errors related to file not found if the folder is empty
				continue
			fi

			if [[ ! -e ../${file} ]]; then # this means there is a transcript pending review!
				if [[ ! -e ${repo_root}/site_review_email_body.txt ]]; # if this is first one flagged add an intro to newly created email body txt
					echo "Action required - transcripts needing manual review!" > "$repo_root"/site_review_email_body.txt
					echo "The following is a list of transcripts still pending redaction review for this site:" >> "$repo_root"/site_review_email_body.txt
					echo "(note that there may be an ~1 day lag between correctly approving a transcript and it being registered by the interview pipeline)" >> "$repo_root"/site_review_email_body.txt
				fi
				# now add the file name to the list, set up like bullet points
				echo "	*	${file}" >> "$repo_root"/site_review_email_body.txt
			fi
		done
		cd ../../.. # leave the transcription folder once loop is done
	fi
	if [[ -d psychs/transcripts/prescreening ]];
		cd psychs/transcripts/prescreening
		for file in *.txt; do
			if [[ ! -e $file ]]; then # make sure don't get errors related to file not found if the folder is empty
				continue
			fi

			if [[ ! -e ../${file} ]]; then # this means there is a transcript pending review!
				if [[ ! -e ${repo_root}/site_review_email_body.txt ]]; # if this is first one flagged add an intro to newly created email body txt
					echo "Action required - transcripts needing manual review!" > "$repo_root"/site_review_email_body.txt
					echo "The following is a list of transcripts still pending redaction review for this site:" >> "$repo_root"/site_review_email_body.txt
					echo "(note that there may be an ~1 day lag between correctly approving a transcript and it being registered by the interview pipeline)" >> "$repo_root"/site_review_email_body.txt
				fi
				# now add the file name to the list, set up like bullet points
				echo "	*	${file}" >> "$repo_root"/site_review_email_body.txt
			fi
		done
		cd ../../.. # leave the transcription folder once loop is done
	fi

	# return to study root once done with the patient's transcripts
	cd "$data_root"/PROTECTED/"$study"/processed
done