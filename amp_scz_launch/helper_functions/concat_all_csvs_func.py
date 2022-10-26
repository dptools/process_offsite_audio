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

	# that is end of function, as outputs will be accessed by a second python function
	return
	
if __name__ == '__main__':
	# Map command line arguments to function arguments.
	concat_site_csv(sys.argv[1], sys.argv[2])
