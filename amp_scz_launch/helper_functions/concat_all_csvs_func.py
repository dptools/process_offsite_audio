#!/usr/bin/env python

import os
import sys
import glob
import pandas as pd
import numpy as np

# makes 2 warning and 2 summary related CSVs for across all sites
def concat_site_csv(data_root, output_root):
	# start by getting paths for the csvs to concat into the 4 csvs of interest
	os.chdir(data_root)
	summary_stat_paths = glob.glob(os.path.join("GENERAL", "*", "processed", "*", "interviews", "*", "*InterviewSummaryStatsLog.csv"))
	accounting_paths = glob.glob(os.path.join("PROTECTED", "*", "processed", "*", "interviews", "*", "*InterviewAllModalityProcessAccountingTable.csv"))
	warning_paths = glob.glob(os.path.join("PROTECTED", "*", "processed", "*", "interviews", "*", "*InterviewProcessWarningsTable.csv"))
	sop_paths = glob.glob(os.path.join("PROTECTED", "*", "processed", "*", "interviews", "*", "*RawInterviewSOPAccountingTable.csv"))

	# initialize the dfs to concat into
	summary_stat_df = pd.DataFrame()
	accounting_df = pd.DataFrame()
	warning_df = pd.DataFrame()
	sop_df = pd.DataFrame()

	# combine the existing qc stat dfs
	for cur_path in summary_stat_paths:
		cur_df = pd.read_csv(cur_path)
		cur_df = cur_df.iloc[-2:] # for summary stats specifically only want latest results, so take last 2 rows only
		cur_int_type = cur_path.split("/")[-2]
		cur_ptid = cur_path.split("/")[-4]
		cur_site = cur_path.split("/")[-6]
		cur_df["siteID"] = [cur_site for x in range(cur_df.shape[0])]
		cur_df["subjectID"] = [cur_ptid for x in range(cur_df.shape[0])]
		cur_df["interview_type"] = [cur_int_type for x in range(cur_df.shape[0])]

		if summary_stat_df.empty:
			summary_stat_df = cur_df
		else:
			summary_stat_df = pd.concat([summary_stat_df, cur_df])

	# now combine for accounting
	for cur_path in accounting_paths:
		cur_df = pd.read_csv(cur_path)
		cur_int_type = cur_path.split("/")[-2]
		cur_ptid = cur_path.split("/")[-4]
		cur_site = cur_path.split("/")[-6]
		cur_df["siteID"] = [cur_site for x in range(cur_df.shape[0])]
		cur_df["subjectID"] = [cur_ptid for x in range(cur_df.shape[0])]
		cur_df["interview_type"] = [cur_int_type for x in range(cur_df.shape[0])]

		if accounting_df.empty:
			accounting_df = cur_df
		else:
			accounting_df = pd.concat([accounting_df, cur_df])

	# again repeat for process warnings
	for cur_path in warning_paths:
		cur_df = pd.read_csv(cur_path)
		cur_int_type = cur_path.split("/")[-2]
		cur_ptid = cur_path.split("/")[-4]
		cur_site = cur_path.split("/")[-6]
		cur_df["siteID"] = [cur_site for x in range(cur_df.shape[0])]
		cur_df["subjectID"] = [cur_ptid for x in range(cur_df.shape[0])]
		cur_df["interview_type"] = [cur_int_type for x in range(cur_df.shape[0])]

		if warning_df.empty:
			warning_df = cur_df
		else:
			warning_df = pd.concat([warning_df, cur_df])

	# finally repeat for SOP
	for cur_path in sop_paths:
		cur_df = pd.read_csv(cur_path)
		cur_int_type = cur_path.split("/")[-2]
		cur_ptid = cur_path.split("/")[-4]
		cur_site = cur_path.split("/")[-6]
		cur_df["siteID"] = [cur_site for x in range(cur_df.shape[0])]
		cur_df["subjectID"] = [cur_ptid for x in range(cur_df.shape[0])]
		cur_df["interview_type"] = [cur_int_type for x in range(cur_df.shape[0])]

		if sop_df.empty:
			sop_df = cur_df
		else:
			sop_df = pd.concat([sop_df, cur_df])

	# clean up and save each df! don't need to worry about overwriting anything, just save directly to the output path
	summary_stat_df.reset_index(drop=True, inplace=True)
	accounting_df.reset_index(drop=True, inplace=True)
	warning_df.reset_index(drop=True, inplace=True)
	sop_df.reset_index(drop=True, inplace=True)
	summary_stat_df.to_csv(os.path.join(output_root,"all-QC-summary-stats.csv"), index=False)
	accounting_df.to_csv(os.path.join(output_root,"all-processed-accounting.csv"), index=False)
	warning_df.to_csv(os.path.join(output_root,"all-processed-warnings.csv"), index=False)
	sop_df.to_csv(os.path.join(output_root,"all-SOP-warnings.csv"), index=False)

	# now adding in the concatenated row by row QC record too - these are already set up, so it's a simple concat, don't need to monitor edge cases
	individual_qc_paths = glob.glob(os.path.join(data_root, "GENERAL", "*", "processed", "*", "interviews", "*", "*_combinedQCRecords.csv"))
	individual_qc_dfs = [pd.read_csv(x) for x in individual_qc_paths]
	individual_qc_concat = pd.concat(individual_qc_dfs)
	individual_qc_concat.reset_index(drop=True, inplace=True)
	individual_qc_concat.to_csv(os.path.join(output_root,"combined-QC.csv"), index=False)

	# do a per subject count for open interviews to supplement the added DPDash chart views
	counting_columns = ["open_interview_processed_count","num_unique_days","count_within_first_month","count_after_first_month","first_day","first_last_gap_in_days",
						"open_interview_processed_videos","open_interview_quality_videos","open_interview_processed_transcripts","open_interview_quality_transcripts",
						"open_transcripts_within_first_month","open_transcripts_after_first_month","availability_category_estimate"]
	counting_vals = [[] for x in range(len(counting_columns))]
	subjects_list = []
	for subject_id in set(individual_qc_concat["patient"].tolist()):
		cur_pt_check = individual_qc_concat[(individual_qc_concat["patient"]==subject_id) & (individual_qc_concat["interview_type"]=="open")]
		total_open_count = cur_pt_check.shape[0]
		if total_open_count > 0:
			num_unique_days = len(set(cur_pt_check["day"].tolist()))
			df_with_video = cur_pt_check.dropna(subset=["mean_faces_detected_in_frame"])
			num_with_video = df_with_video.shape[0]
			num_with_video_excellent = df_with_video[(df_with_video["mean_faces_detected_in_frame"]>1.8) & (df_with_video["mean_faces_detected_in_frame"]<2.1)].shape[0]
			df_with_trans = cur_pt_check.dropna(subset=["num_inaudible"])
			num_with_trans = df_with_trans.shape[0]
			num_with_trans_excellent = df_with_trans[df_with_trans["num_inaudible"]<0.01].shape[0]
			num_in_first_month = cur_pt_check[cur_pt_check["day"]<=30].shape[0]
			num_past_first_month = cur_pt_check[cur_pt_check["day"]>30].shape[0]
			num_with_trans_first_month = df_with_trans[df_with_trans["day"]<=30].shape[0]
			num_with_trans_past_first = df_with_trans[df_with_trans["day"]>30].shape[0]
			if num_with_trans_first_month > 0:
				if num_with_trans_past_first > 0:
					avail_cat = 3 # category for both desired time points likely having transcripts
				else:
					avail_cat = 1 # category for only baseline
			else:
				if num_with_trans_past_first > 0:
					avail_cat = 2 # category for only 2 month transcript
				else:
					avail_cat = 0 # category for neither
			if total_open_count > 1:
				cur_days_list = cur_pt_check["day"].tolist()
				cur_days_list.sort()
				first_day = cur_days_list[0]
				first_last_gap = cur_days_list[-1] - first_day
			else:
				first_last_gap = 0
				first_day = cur_pt_check["day"].tolist()[0]
		else:
			num_unique_days = 0
			num_with_video = 0
			num_with_video_excellent = 0
			num_with_trans = 0
			num_with_trans_excellent = 0
			num_in_first_month = 0
			num_past_first_month = 0
			num_with_trans_first_month = 0
			num_with_trans_past_first = 0
			avail_cat = 0 # no baseline nor 2 month follow-up estimated
			first_last_gap = 0
			first_day = 0
		cur_pt_vals = [total_open_count, num_unique_days, num_in_first_month, num_past_first_month, first_day, first_last_gap, num_with_video, num_with_video_excellent, 
					   num_with_trans, num_with_trans_excellent, num_with_trans_first_month, num_with_trans_past_first, avail_cat]
		for ind in range(len(cur_pt_vals)):
			counting_vals[ind].append(cur_pt_vals[ind])
		subjects_list.append(subject_id)
	sites_list = [s[:2] for s in subjects_list]
	new_subj_df = pd.DataFrame()
	new_subj_df["site"] = sites_list
	new_subj_df["subject"] = subjects_list
	for c in range(len(counting_columns)):
		new_subj_df[counting_columns[c]] = counting_vals[c]
	new_subj_df.sort_values(by="subject",inplace=True)
	new_subj_df.to_csv(os.path.join(output_root,"open-counts-by-subject.csv"), index=False)

	# that is end of function, as outputs will be accessed by a second python function
	return
	
if __name__ == '__main__':
	# Map command line arguments to function arguments.
	concat_site_csv(sys.argv[1], sys.argv[2])
