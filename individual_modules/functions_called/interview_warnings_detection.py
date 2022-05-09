#!/usr/bin/env python

import os
import sys
import glob
import pandas as pd
import numpy as np

def interview_warnings_check(interview_type, data_root, study, ptID, warning_lab_email_path, summary_lab_email_path):
	# note the accounting CSV columns
	audio_column_names = ["day", "interview_number", "interview_date", "interview_time", "raw_audio_path", "processed_audio_filename", 
						  "audio_process_date", "accounting_date", "consent_date_at_accounting",
						  "audio_success_bool", "audio_rejected_bool", "auto_upload_failed_bool",
						  "single_file_bool", "video_raw_path", "top_level_m4a_count", "top_level_mp4_count", 
						  "speaker_specific_file_count", "speaker_specific_valid_m4a_count", "speaker_specific_unique_ID_count"]
	video_column_names = ["interview_date", "interview_time", "processed_video_filename", "video_day", "video_interview_number", "video_process_date"]
	transcript_column_names = ["day", "interview_number", "returned_transcript_filename", "redacted_transcript_filename", "processed_csv_filename", 
							   "transcript_language", "transcript_encoding_initial", "transcript_encoding_final", "manual_review_bool", "manual_return_bool",
							   "transcript_pulled_date", "transcript_approved_date", "transcript_processed_date",
							   "transcript_pulled_accounting_date", "transcript_approved_accounting_date", "transcript_processed_accounting_date"]

	# navigate to folder of interest, load initial CSVs
	# overall folder must exist when called from bash script
	os.chdir(os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type))
	try:
		audio_accounting = pd.read_csv(study + "_" + ptID + "_" + interview_type + "InterviewAudioProcessAccountingTable.csv")
	except:
		audio_accounting = pd.DataFrame(columns=audio_column_names)
	try:
		video_accounting = pd.read_csv(study + "_" + ptID + "_" + interview_type + "InterviewVideoProcessAccountingTable.csv")
	except:
		video_accounting = pd.DataFrame(columns=video_column_names)
	try:
		trans_accounting = pd.read_csv(study + "_" + ptID + "_" + interview_type + "InterviewTranscriptProcessAccountingTable.csv")
	except:
		trans_accounting = pd.DataFrame(columns=transcript_column_names)

	# do merges
	av_accounting = audio_accounting.merge(video_accounting, on=["interview_date", "interview_time"], how="outer")
	avl_accounting = av_accounting.merge(trans_accounting, on=["day", "interview_number"], how="outer")

	# get current date string for checking against
	today_str = datetime.date.today().strftime("%Y-%m-%d")
	# CSVs that may have new QC to look up
	audio_update_df = avl_accounting[(avl_accounting["audio_process_date"]==today_str) | (avl_accounting["accounting_date"]==today_str)]
	video_update_df = avl_accounting[avl_accounting["video_process_date"]==today_str]
	trans_update_df = avl_accounting[(avl_accounting["transcript_processed_date"]==today_str) | (avl_accounting["transcript_processed_accounting_date"]==today_str)]
	# concat the three types of updates for now
	all_update_df = pd.concat([audio_update_df, video_update_df, trans_update_df])
	
	# also transcripts that may have updates beyond what is relevant to the QC
	trans_pull_df = avl_accounting[(avl_accounting["transcript_pulled_date"]==today_str) | (avl_accounting["transcript_pulled_accounting_date"]==today_str) | (avl_accounting["transcript_approved_date"]==today_str) | (avl_accounting["transcript_approved_accounting_date"]==today_str)]
	# concat the updates DF to look for any accounting-related warnings to add to the warnings DF before proceeding to specific QC issues
	all_new_df = pd.concat([audio_update_df, video_update_df, trans_update_df, trans_pull_df])

	rejected_df = all_new_df[all_new_df["audio_rejected_bool"]==1]
	sftp_fail_df = all_new_df[all_new_df["auto_upload_failed_bool"]==1]
	speakers_count_bad_df = all_new_df[all_new_df["speaker_specific_unique_ID_count"]<2]
	video_day_inconsistent_df = all_new_df[all_new_df["video_day"]!=all_new_df["day"]]
	video_sess_inconsistent_df = all_new_df[all_new_df["video_interview_number"]!=all_new_df["interview_number"]]
	initial_encoding_bad_df = all_new_df[all_new_df["transcript_encoding_initial"]=="INVALID"]
	# only do the non-ASCII warning in this table for non-English transcripts
	final_encoding_warn_df = all_new_df[(all_new_df["transcript_encoding_final"]=="UTF-8") & (all_new_df["transcript_language"]=="ENGLISH")]

	sorted_accounting_csv = avl_accounting.sort_values(by="interview_number")
	sorted_accounting_csv["days_diff"] = sorted_accounting_csv["day"].diff()
	# shift up one so we also get differences associated with the other file being subtracted
	days_diff_shift = sorted_accounting_csv["days_diff"].tolist()[1:]
	days_diff_shift.append(np.nan)
	sorted_accounting_csv["days_diff_shift"] = days_diff_shift
	cur_check = sorted_accounting_csv[(pd.notnull(sorted_accounting_csv["days_diff"])) & (sorted_accounting_csv["days_diff"] < 0)]
	bad_dates_df = all_new_df[(all_new_df["interview_date"].isin(cur_check["interview_date"].tolist())) & (all_new_df["interview_time"].isin(cur_check["interview_time"].tolist()))]
	cur_check = sorted_accounting_csv[(pd.notnull(sorted_accounting_csv["days_diff_shift"])) & (sorted_accounting_csv["days_diff_shift"] < 0)]
	bad_dates_df_2 = all_new_df[(all_new_df["interview_date"].isin(cur_check["interview_date"].tolist())) & (all_new_df["interview_time"].isin(cur_check["interview_time"].tolist()))]

	numbers_list = avl_accounting["interview_number"].tolist()
	if len(numbers_list) != len(list(set(numbers_list))):
		sorted_accounting_csv["sess_diff"] = sorted_accounting_csv["interview_number"].diff()
		# shift up one so we also get differences associated with the other file being subtracted
		sess_diff_shift = sorted_accounting_csv["sess_diff"].tolist()[1:]
		sess_diff_shift.append(np.nan)
		sorted_accounting_csv["sess_diff_shift"] = sess_diff_shift
		cur_check = sorted_accounting_csv[(pd.notnull(sorted_accounting_csv["sess_diff"])) & (sorted_accounting_csv["sess_diff"] == 0)]
		bad_sess_nums_df = all_new_df[(all_new_df["interview_date"].isin(cur_check["interview_date"].tolist())) & (all_new_df["interview_time"].isin(cur_check["interview_time"].tolist()))]
		cur_check = sorted_accounting_csv[(pd.notnull(sorted_accounting_csv["sess_diff_shift"])) & (sorted_accounting_csv["sess_diff_shift"] == 0)]
		bad_sess_nums_df_2 = all_new_df[(all_new_df["interview_date"].isin(cur_check["interview_date"].tolist())) & (all_new_df["interview_time"].isin(cur_check["interview_time"].tolist()))]
	else:
		bad_sess_nums_df = pd.DataFrame(columns=all_new_df.columns)
		bad_sess_nums_df_2 = pd.DataFrame(columns=all_new_df.columns)

	non_new_df = avl_accounting[(~avl_accounting["interview_date"].isin(all_new_df["interview_date"].tolist())) & (~avl_accounting["interview_time"].isin(all_new_df["interview_time"].tolist()))]
	consents_list = list(set(avl_accounting["consent_date_at_accounting"].tolist()))
	if len(consents_list) > 1:
		new_consents_list = list(set(all_new_df["consent_date_at_accounting"].tolist()))
		old_consents_list = list(set(non_new_df["consent_date_at_accounting"].tolist()))
		new_consents_warning = [x for x in new_consents_list if x not in old_consents_list]
		bad_consents_df = all_new_df[all_new_df["consent_date_at_accounting"].isin(new_consents_warning)]
	else:
		bad_consents_df = pd.DataFrame(columns=all_new_df.columns)

	bad_dates_final_df = pd.concat([bad_dates_df, bad_dates_df_2])
	bad_dates_final_df.reset_index(drop=True, inplace=True)
	bad_dates_final_df.drop_duplicates(inplace=True)
	bad_sess_nums_final_df = pd.concat([bad_sess_nums_df, bad_sess_nums_df_2])
	bad_sess_nums_final_df.reset_index(drop=True, inplace=True)
	bad_sess_nums_final_df.drop_duplicates(inplace=True)

	# now load the QC CSVs for those checks
	# start with column name lists as before
	audio_qc_headers=["reftime","day","timeofday","weekday","study","patient","interview_number","length_minutes","overall_db","amplitude_stdev","mean_flatness"]
	video_qc_headers=["reftime","day","timeofday","weekday","study","patient","interview_number",
					  "number_extracted_frames","minimum_faces_detected_in_frame","maximum_faces_detected_in_frame","mean_faces_detected_in_frame", 
					  "minimum_face_confidence_score","maximum_face_confidence_score","mean_face_confidence_score",
					  "minimum_face_area","maximum_face_area","mean_face_area"]
	trans_qc_headers=["reftime","day","timeofday","weekday","study","patient","interview_number","transcript_name","num_subjects",
					  "num_turns_S1","num_words_S1","min_words_in_turn_S1","max_words_in_turn_S1",
					  "num_turns_S2","num_words_S2","min_words_in_turn_S2","max_words_in_turn_S2",
					  "num_turns_S3","num_words_S3","min_words_in_turn_S3","max_words_in_turn_S3",
					  "num_inaudible","num_questionable","num_crosstalk","num_redacted","num_commas","num_dashes",
					  "final_timestamp_minutes","min_timestamp_space","max_timestamp_space","min_timestamp_space_per_word","max_timestamp_space_per_word"]
	# overall folder must exist when called from bash script
	os.chdir(os.path.join(data_root, "GENERAL", study, "processed", ptID, "interviews", interview_type))
	# for this project the DPDash CSV name only uses avlqc identifier, not site ID
	audio_dpdash_name_format = "avlqc" + "-" + ptID + "-interviewMonoAudioQC_" + interview_type + "-day*.csv"
	try:
		audio_dpdash_name = glob.glob(audio_dpdash_name_format)[0] # DPDash script deletes any older days in this subfolder, so should only get 1 match each time
		audio_dpdash_qc = pd.read_csv(audio_dpdash_name)
	except:
		audio_dpdash_qc = pd.DataFrame(columns=audio_qc_headers)
	video_dpdash_name_format = "avlqc" + "-" + ptID + "-interviewVideoQC_" + interview_type + "-day*.csv"
	try:
		video_dpdash_name = glob.glob(video_dpdash_name_format)[0] # DPDash script deletes any older days in this subfolder, so should only get 1 match each time
		video_dpdash_qc = pd.read_csv(video_dpdash_name)
	except:
		video_dpdash_qc = pd.DataFrame(columns=video_qc_headers)
	trans_dpdash_name_format = "avlqc" + "-" + ptID + "-interviewRedactedTranscriptQC_" + interview_type + "-day*.csv"
	try:
		trans_dpdash_name = glob.glob(trans_dpdash_name_format)[0] # DPDash script deletes any older days in this subfolder, so should only get 1 match each time
		trans_dpdash_qc = pd.read_csv(trans_dpdash_name)
	except:
		trans_dpdash_qc = pd.DataFrame(columns=trans_qc_headers)

	# check for less than 4 minutes, 0 redactions, 0 faces
	cur_check = audio_dpdash_qc[audio_dpdash_qc["length_minutes"]<4]
	short_length_df = all_update_df[(all_update_df["day"].isin(cur_check["day"].tolist())) & (all_update_df["interview_number"].isin(cur_check["interview_number"].tolist()))]
	cur_check = video_dpdash_qc[video_dpdash_qc["mean_faces_detected_in_frame"]==0]
	no_face_df = all_update_df[(all_update_df["video_day"].isin(cur_check["day"].tolist())) & (all_update_df["video_interview_number"].isin(cur_check["interview_number"].tolist()))]
	cur_check = trans_dpdash_qc[trans_dpdash_qc["num_redacted"]==0]
	no_redact_df = all_update_df[(all_update_df["day"].isin(cur_check["day"].tolist())) & (all_update_df["interview_number"].isin(cur_check["interview_number"].tolist()))]
	
	# move back to PROTECTED side before processing what has been loaded
	# overall folder must exist when called from bash script
	os.chdir(os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type))

	# put together warning df with necessary info
	new_cols = ["day", "interview_number", "interview_date", "interview_time", "warning_text"]
	warned_days = []
	warned_numbers = []
	warned_dates = []
	warned_times = []
	warned_texts = []
	warning_dfs = [rejected_df, sftp_fail_df, speakers_count_bad_df, video_day_inconsistent_df, video_sess_inconsistent_df, initial_encoding_bad_df, final_encoding_warn_df, 
				   bad_consents_df, bad_dates_final_df, bad_sess_nums_final_df, short_length_df, no_face_df, no_redact_df]
	warning_text_template = ["Audio Rejected by QC", "Audio Failed SFTP Upload", "Missing Expected Speaker Specific Audios", 
							 "Video Day Inconsistent with Audio Day", "Video Number Inconsistent with Audio Number", 
							 "Transcript Encoding Not UTF-8", "English Transcript Encoding Not ASCII",
							 "Consent Date Changed with New Files", "Session and Day Numbers Inconsistent", "Session Number Repeated",
							 "Interview Under 4 Minutes", "No Faces Detected", "No Redactions Detected"]
	non_empty_warnings = [(x,y) for x,y in zip(warning_dfs,warning_text_template) if not x.empty]
	if len(non_empty_warnings) > 0:
		for info in non_empty_warnings:
			cur_df = info[0]
			cur_message = info[1]
			warned_days.extend(cur_df["day"].tolist())
			warned_numbers.extend(cur_df["interview_number"].tolist())
			warned_dates.extend(cur_df["interview_date"].tolist())
			warned_times.extend(cur_df["interview_time"].tolist())
			warned_texts.extend([cur_message] for x in range(len(cur_df.shape[0])))

		final_warning_df = pd.DataFrame()
		values = [warned_days, warned_numbers, warned_dates, warned_times, warned_texts]
		for header,value in zip(new_cols,values):
			final_warning_df[header] = value
		final_warning_df["warning_date"] = [today_str for x in range(len(final_warning_df.shape[0]))]

		# will now save this DF, first confirming there is nothing else to concat with first, otherwise need to join that first
		warn_output_path = study + "_" + ptID + "_" + interview_type + "InterviewProcessWarningsTable.csv"
		if os.path.exists(warn_output_path):
			existing_df = pd.read_csv(warn_output_path)
			join_csv = pd.concat([existing_df, final_warning_df])
			join_csv.reset_index(drop=True, inplace=True)
			join_csv.to_csv(warn_output_path, index=False)
		else:
			final_warning_df.to_csv(warn_output_path, index=False)
	
	# at end if have the warnings email path need to look up the SOP violation CSV path
	# if either that has new warnings or any of the above warnings triggered, will write the info to the warnings email (initializing first if needed)
	if warning_lab_email_path is not None:
		if os.path.exists(study + "_" + ptID + "_" + interview_type + "RawInterviewSOPAccountingTable.csv"):
			cur_sop_df = pd.read_csv(study + "_" + ptID + "_" + interview_type + "RawInterviewSOPAccountingTable.csv")
			new_sop_issues = cur_sop_df[cur_sop_df["date_detected"]==today_str]
			# if we have sop issues, write those first - after confirming that the email has a basic header
			if not new_sop_issues.empty:
				if not os.path.exists(warning_lab_email_path):
					with open(warning_lab_email_path, 'w') as fw:
						fw.write("Potential issues found with newly uploaded and/or newly processed interviews for this site! Each interview with new violations is listed below, grouped by patient and interview type. Note that these alerts will only appear when a recently updated file is flagged - not receiving the warning in the future is not an indication it was resolved.")
						fw.write("\n")
						fw.write("\n")
						fw.write("For any detected file organization problems, the raw interview folder name will be listed. Please review the name and contents of this folder on source to address any problems before the interview can be processed. Be aware that Lochness does not delete or rename files that are already pulled, so renaming will result in a new file copy on the server. Please contact the engineering team if this is an issue.")
						fw.write("\n")
						fw.write("Note also that the SOP violation check looks for raw interviews that have already been pulled to PHOENIX but still have naming convention issues - see Lochness email alerts for interviews that were not even pulled to PHOENIX due to their violations.")
						fw.write("\n")
						fw.write("\n")
						fw.write("The current warnings that are covered for processed interviews include inconsistencies in renaming (likely caused by changing consent date or uploading older interviews after newer ones), unexpected transcript file encoding, severe issues with interview or transcript quality (e.g. 0 faces detected across extracted frames, 0 redactions found across transcript), and failure of audio to upload to TranscribeMe (due to either intentional rejection or connectivity problems).")
						fw.write("\n")
						fw.write("Each processed file warning will include a description along with the flagged interview's day number and session number. These files will continue to be processed as possible, so please decide if there needs to be manual intervention on a case by case basis, and if so contact the engineering team.")
						fw.write("\n")
						fw.write("Note also that these warnings are not an exhaustive list of problems that could occur. Continue to monitor DPDash and the modality-specific summary emails to ensure as many unexpected concerns are caught as possible.")
						fw.write("\n")
						fw.write("\n")

				# now write stuff specific to this
				raw_names_violate = new_sop_issues["raw_name"].tolist()
				with open(warning_lab_email_path, 'a') as fa:
					fa.write("--- Newly Detected SOP Violations for " + ptID + " " + interview_type + " ---")
					fa.write("\n")
					for cur_name in raw_names_violate:
						fa.write(cur_name)
						fa.write("\n")
					fa.write("\n")

		# once done with the sop checks, write processed warning info if new relevant warnings
		if len(non_empty_warnings) > 0:
			# initialize the path to begin with if needed
			if not os.path.exists(warning_lab_email_path):
				with open(warning_lab_email_path, 'w') as fw:
					fw.write("Potential issues found with newly uploaded and/or newly processed interviews for this site! Each interview with new violations is listed below, grouped by patient and interview type. Note that these alerts will only appear when a recently updated file is flagged - not receiving the warning in the future is not an indication it was resolved.")
					fw.write("\n")
					fw.write("\n")
					fw.write("For any detected file organization problems, the raw interview folder name will be listed. Please review the name and contents of this folder on source to address any problems before the interview can be processed. Be aware that Lochness does not delete or rename files that are already pulled, so renaming will result in a new file copy on the server. Please contact the engineering team if this is an issue.")
					fw.write("\n")
					fw.write("Note also that the SOP violation check looks for raw interviews that have already been pulled to PHOENIX but still have naming convention issues - see Lochness email alerts for interviews that were not even pulled to PHOENIX due to their violations.")
					fw.write("\n")
					fw.write("\n")
					fw.write("The current warnings that are covered for processed interviews include inconsistencies in renaming (likely caused by changing consent date or uploading older interviews after newer ones), unexpected transcript file encoding, severe issues with interview or transcript quality (e.g. 0 faces detected across extracted frames, 0 redactions found across transcript), and failure of audio to upload to TranscribeMe (due to either intentional rejection or connectivity problems).")
					fw.write("\n")
					fw.write("Each processed file warning will include a description along with the flagged interview's day number and session number. These files will continue to be processed as possible, so please decide if there needs to be manual intervention on a case by case basis, and if so contact the engineering team.")
					fw.write("\n")
					fw.write("Note also that these warnings are not an exhaustive list of problems that could occur. Continue to monitor DPDash and the modality-specific summary emails to ensure as many unexpected concerns are caught as possible.")
					fw.write("\n")
					fw.write("\n")

			# now write specific stuff for this regardless
			with open(warning_lab_email_path, 'a') as fa:
				fa.write("--- Newly Detected Processing Warnings for " + ptID + " " + interview_type + " ---")
				fa.write("\n")
				for possible_index in range(len(warned_days)):
					w_day_str = str(warned_days[possible_index])
					w_sess_str = str(warned_numbers[possible_index])
					w_message = warned_texts[possible_index]
					fa.write(interview_type + " session " + w_sess_str + " (day " + w_day_str + "): " + w_message)
					fa.write("\n")
				fa.write("\n")
			
	# and similarly need to initialize the summary email if have't already, assuming there is new processing
	if summary_lab_email_path is not None and not all_update_df.empty:
		if not os.path.exists(summary_lab_email_path):
			with open(summary_lab_email_path, 'w') as fw:
				fw.write("Today's pipeline run has resulted in interview file processing updates. This email provides the latest version of the complete site-wide QC summary stats, as well as the following list of those patient interview types with updates:")
				fw.write("\n")
				fw.write(ptID + " (" + interview_type + ")")
		else:
			with open(summary_lab_email_path, 'a') as fa:
				fa.write(", " + ptID)

	# finally save the merged CSV if there is anything new to report - since it contains everything to date can just overwrite
	if not all_new_df.empty:
		avl_accounting.to_csv(study + "_" + ptID + "_" + interview_type + "InterviewAllModalityProcessAccountingTable.csv", index=False)
	
if __name__ == '__main__':
    # Map command line arguments to function arguments.
    try:
    	warning_lab_email_path = sys.argv[5]
    	summary_lab_email_path = sys.argv[6]
    except:
    	warning_lab_email_path = None
    	summary_lab_email_path = None

    interview_warnings_check(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], warning_lab_email_path, summary_lab_email_path)
