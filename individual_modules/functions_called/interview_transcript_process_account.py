#!/usr/bin/env python

import os
import sys
import datetime
import glob
import pandas as pd
import numpy as np

# final step of transcript pipeline is to do various file accounting! will merge with what was done as part of audio pipeline (on day and interview number variables)
def interview_transcript_account(interview_type, data_root, study, ptID, language_used):
	# start with looking up existing transcript
	os.chdir(os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type))
	try:
		prev_account = pd.read_csv(study + "_" + ptID + "_" + interview_type + "InterviewTranscriptProcessAccountingTable.csv")
		transcribed_list = prev_account["returned_transcript_filename"].tolist()
		redacted_list = prev_account["redacted_transcript_filename"].tolist()
		processed_list = prev_account["processed_csv_filename"].tolist()
	except:
		transcribed_list = []
		redacted_list = []
		processed_list = []	

	# column names list to be used
	column_names = ["day", "interview_number", "returned_transcript_filename", "redacted_transcript_filename", "processed_csv_filename", 
					"transcript_language", "transcript_encoding_initial", "transcript_encoding_final", "manual_review_bool", "manual_return_bool",
					"transcript_pulled_date", "transcript_approved_date", "transcript_processed_date",
					"transcript_pulled_accounting_date", "transcript_approved_accounting_date", "transcript_processed_accounting_date"]
	# initialize lists to track all these variables
	day_list = []
	interview_number_list = []
	returned_transcript_filename_list = []
	redacted_transcript_filename_list = []
	processed_csv_filename_list = []
	transcript_language_list = []
	transcript_encoding_initial_list = []
	transcript_encoding_final_list = []
	manual_review_bool_list = []
	manual_return_bool_list = []
	transcript_pulled_date_list = []
	transcript_approved_date_list = []
	transcript_processed_date_list = []
	transcript_pulled_accounting_date_list = []
	transcript_approved_accounting_date_list = []
	transcript_processed_accounting_date_list = []

	# get current date string for accounting purposes
	today_str = datetime.date.today().strftime("%Y-%m-%d")

	# get the various lists of transcript names currently on the server
	cur_prescreen_trans = glob.glob(os.path.join(data_root,"PROTECTED", study, "processed", ptID, "interviews", interview_type, "transcripts/prescreening", "*.txt"))
	cur_approved_trans = glob.glob(os.path.join(data_root,"PROTECTED", study, "processed", ptID, "interviews", interview_type, "transcripts", "*.txt"))
	cur_redacted_trans = glob.glob(os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts", "*.txt"))
	cur_csvs = glob.glob(os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts/csv", "*.csv"))

	# first look for new transcripts under prescreening
	for reviewed_trans in cur_prescreen_trans:
		fname = reviewed_trans.split("/")[-1]
		if fname in transcribed_list: # if already processed can skip this part of loop
			continue

		# first append the stuff that always happens for prescreened transcripts
		day_list.append(int(fname.split("_day")[1].split("_")[0]))
		interview_number_list.append(int(fname.split("_session")[1].split(".")[0]))
		returned_transcript_filename_list.append(fname)
		transcript_language_list.append(language_used)
		manual_review_bool_list.append(1)
		last_modified_date = datetime.datetime.fromtimestamp(os.path.getmtime(reviewed_trans)).date().strftime("%Y-%m-%d")
		transcript_pulled_date_list.append(last_modified_date)
		transcript_pulled_accounting_date_list.append(today_str)
		# check for ascii, then if not check for utf8. if that fails we have a problem
		with open(reviewed_trans, 'rb') as fd:
			ascii_bool = fd.read().isascii()
		if not ascii_bool:
			try:
				ftest = open(reviewed_trans, encoding="utf-8", errors="strict")
				transcript_encoding_initial_list.append("UTF-8")
			except:
				transcript_encoding_initial_list.append("INVALID")
		else:
			transcript_encoding_initial_list.append("ASCII")

		# then check if perhaps other processing has occured - first look for returned
		if os.path.exists("../" + fname):
			manual_return_bool_list.append(1)
		else:
			manual_return_bool_list.append(0)

		# next look for redacted - generally this should coincide with the returned from approval, so most vars just associated with this instead of the above
		if os.path.exists(os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts", fname.split(".")[0] + "_REDACTED.txt")):
			redacted_transcript_filename_list.append(fname.split(".")[0] + "_REDACTED.txt")
			cur_path = os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts", fname.split(".")[0] + "_REDACTED.txt")
			last_modified_date = datetime.datetime.fromtimestamp(os.path.getmtime(cur_path)).date().strftime("%Y-%m-%d")
			transcript_approved_date_list.append(last_modified_date)
			transcript_approved_accounting_date_list.append(today_str)
			# preemptively check if the transcript itself is ascii - should never have csv without having the redacted txt
			with open(cur_path, 'rb') as fd:
				ascii_bool = fd.read().isascii()
		else:
			redacted_transcript_filename_list.append("")
			transcript_approved_date_list.append("")
			transcript_approved_accounting_date_list.append("")

		# now look for successful CSV creation
		if os.path.exists(os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts/csv", fname.split(".")[0] + "_REDACTED.csv")):
			processed_csv_filename_list.append(fname.split(".")[0] + "_REDACTED.csv")
			cur_path = os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts/csv", fname.split(".")[0] + "_REDACTED.csv")
			last_modified_date = datetime.datetime.fromtimestamp(os.path.getmtime(cur_path)).date().strftime("%Y-%m-%d")
			transcript_processed_date_list.append(last_modified_date)
			transcript_processed_accounting_date_list.append(today_str)
			if ascii_bool:
				transcript_encoding_final_list.append("ASCII")
			else:
				# there should never be a CSV if the source txt is not at least UTF-8!
				transcript_encoding_final_list.append("UTF-8")
		else:
			processed_csv_filename_list.append("")
			transcript_processed_date_list.append("")
			transcript_processed_accounting_date_list.append("")
			transcript_encoding_final_list.append("")

	# now look for new transcripts that were not sent for prescreen
	for final_trans in cur_approved_trans:
		fname = final_trans.split("/")[-1]
		if fname in transcribed_list: # if already registered as pulled from transcribeme can skip this part of loop
			# however first will quickly check if it was sent for manual review, if so that means it has been returned and previous df ought to be updated before continuing
			filter_df = prev_account[prev_account["returned_transcript_filename"] == fname]
			if filter_df["manual_review_bool"].tolist()[0] == 1:
				prev_account.loc[prev_account["returned_transcript_filename"]==fname, "manual_return_bool"] = 1
			continue
		if fname in returned_transcript_filename_list: # also skip if it was just covered under the manual review of new return check
			continue

		# so if at this point, we know we have a new transcript from TranscribeMe that was NOT sent for manunal review, so it should be all the way through redaction step
		day_list.append(int(fname.split("_day")[1].split("_")[0]))
		interview_number_list.append(int(fname.split("_session")[1].split(".")[0]))
		returned_transcript_filename_list.append(fname)
		transcript_language_list.append(language_used)
		manual_review_bool_list.append(0)
		last_modified_date = datetime.datetime.fromtimestamp(os.path.getmtime(final_trans)).date().strftime("%Y-%m-%d")
		transcript_pulled_date_list.append(last_modified_date)
		transcript_pulled_accounting_date_list.append(today_str)
		# check for ascii, then if not check for utf8. if that fails we have a problem
		with open(final_trans, 'rb') as fd:
			ascii_bool = fd.read().isascii()
		if not ascii_bool:
			try:
				ftest = open(final_trans, encoding="utf-8", errors="strict")
				transcript_encoding_initial_list.append("UTF-8")
			except:
				transcript_encoding_initial_list.append("INVALID")
		else:
			transcript_encoding_initial_list.append("ASCII")
		# not being reviewed so whether it is returned or not is irrelevant
		manual_return_bool_list.append(np.nan)
		# transcript approved date is also irrelevant in this instance
		transcript_approved_date_list.append(np.nan)
		transcript_approved_accounting_date_list.append(np.nan)

		# look for redacted, which really should exist given that we know the transcript didn't go for review
		if os.path.exists(os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts", fname.split(".")[0] + "_REDACTED.txt")):
			redacted_transcript_filename_list.append(fname.split(".")[0] + "_REDACTED.txt")
			cur_path = os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts", fname.split(".")[0] + "_REDACTED.txt")
			# preemptively check if the transcript itself is ascii - should never have csv without having the redacted txt
			with open(cur_path, 'rb') as fd:
				ascii_bool = fd.read().isascii()
		else:
			redacted_transcript_filename_list.append("")

		# now look for successful CSV creation
		if os.path.exists(os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts/csv", fname.split(".")[0] + "_REDACTED.csv")):
			processed_csv_filename_list.append(fname.split(".")[0] + "_REDACTED.csv")
			cur_path = os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts/csv", fname.split(".")[0] + "_REDACTED.csv")
			last_modified_date = datetime.datetime.fromtimestamp(os.path.getmtime(cur_path)).date().strftime("%Y-%m-%d")
			transcript_processed_date_list.append(last_modified_date)
			transcript_processed_accounting_date_list.append(today_str)
			if ascii_bool:
				transcript_encoding_final_list.append("ASCII")
			else:
				# there should never be a CSV if the source txt is not at least UTF-8!
				transcript_encoding_final_list.append("UTF-8")
		else:
			processed_csv_filename_list.append("")
			transcript_processed_date_list.append("")
			transcript_processed_accounting_date_list.append("")
			transcript_encoding_final_list.append("")

	# now look for new redacted CSVs
	for redacted_trans in cur_redacted_trans:
		fname = redacted_trans.split("/")[-1]
		if fname in redacted_list: # if already registered as redacted can skip this part of loop
			continue
		if fname in redacted_transcript_filename_list: # also skip if this is a new transcript that was already counted as redacted above
			continue

		# if at this point we know we have entries in the previously saved DF to edit
		returned_name = fname.split("_REDACTED")[0] + ".txt" # get the og name to look it up in DF
		# set redacted name
		prev_account.loc[prev_account["returned_transcript_filename"]==returned_name, "redacted_transcript_filename"] = fname
		# after adding redacted name, see if the transcript was manually reviewed (most likely if here), if so update the dates of approval
		filter_df = prev_account[prev_account["returned_transcript_filename"] == returned_name]
		if filter_df["manual_review_bool"].tolist()[0] == 1:
			last_modified_date = datetime.datetime.fromtimestamp(os.path.getmtime(redacted_trans)).date().strftime("%Y-%m-%d")
			prev_account.loc[prev_account["returned_transcript_filename"]==returned_name, "transcript_approved_date"] = last_modified_date
			prev_account.loc[prev_account["returned_transcript_filename"]==returned_name, "transcript_approved_accounting_date"] = today_str

	for csv_trans in cur_csvs:
		fname = csv_trans.split("/")[-1]
		if fname in processed_list: # if already registered as processed can skip this part of loop
			continue
		if fname in processed_csv_filename_list: # also skip if this is a new CSV that was alredy counted above
			continue

		# if at this point we know we have entries in the previously saved DF to edit, similar to above
		redacted_name = fname.split(".csv")[0] + ".txt"
		prev_account.loc[prev_account["redacted_transcript_filename"]==redacted_name, "processed_csv_filename"] = fname
		last_modified_date = datetime.datetime.fromtimestamp(os.path.getmtime(csv_trans)).date().strftime("%Y-%m-%d")
		prev_account.loc[prev_account["redacted_transcript_filename"]==redacted_name, "transcript_processed_date"] = last_modified_date
		prev_account.loc[prev_account["redacted_transcript_filename"]==redacted_name, "transcript_processed_accounting_date"] = today_str

		# finally just have to check encoding to update that record
		redacted_path = "../" + redacted_name
		with open(redacted_path, 'rb') as fd:
			ascii_bool = fd.read().isascii()
		if ascii_bool:
			prev_account.loc[prev_account["redacted_transcript_filename"]==redacted_name, "transcript_encoding_final"] = "ASCII"
		else:
			prev_account.loc[prev_account["redacted_transcript_filename"]==redacted_name, "transcript_encoding_final"] = "UTF-8"

	# construct CSV now
	values_list = [day_list, interview_number_list, returned_transcript_filename_list, redacted_transcript_filename_list, processed_csv_filename_list,
				   transcript_language_list, transcript_encoding_initial_list, transcript_encoding_final_list, manual_review_bool_list, manual_return_bool_list,
				   transcript_pulled_date_list, transcript_approved_date_list, transcript_processed_date_list, 
				   transcript_pulled_accounting_date_list, transcript_approved_accounting_date_list, transcript_processed_accounting_date_list]
	new_df = pd.DataFrame()
	for header,value in zip(column_names, values_list):
		new_df[header] = value

	# saving
	output_path = "../" + study + "_" + ptID + "_" + interview_type + "InterviewTranscriptProcessAccountingTable.csv"
	# concat the updated prior accounting with any newly found files where that is relevant
	if len(transcribed_list) > 0 and not new_df.empty: # in this case have exiting df and new files
		join_df = pd.concat([prev_account, new_df])
		join_df.reset_index(drop=True, inplace=True)
		join_df.to_csv(output_path, index=False)
	elif len(transcribed_list) > 0: # in this case it is just an existing df, but it very well may be updated, so resave
		prev_account.to_csv(output_path, index=False)
	elif not new_df.empty: # in this final case it is just new df with nothing existing, so save that
		new_df.to_csv(output_path, index=False)

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	interview_transcript_account(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])
