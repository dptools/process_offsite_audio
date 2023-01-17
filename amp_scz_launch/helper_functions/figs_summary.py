import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from datetime import date

def run_summary_operation_figs(input_csv,output_folder,cur_server):
	input_df = pd.read_csv(input_csv)
	input_df["total_words"] = input_df["num_words_S1"] + input_df["num_words_S2"] + input_df["num_words_S3"] # note if num subjects > 3 this will be off though
	input_df["total_turns"] = input_df["num_turns_S1"] + input_df["num_turns_S2"] + input_df["num_turns_S3"] # note if num subjects > 3 this will be off though
	input_df["inaudible_per_word"] = input_df["num_inaudible"]/input_df["total_words"]
	input_df["redacted_per_word"] = input_df["num_redacted"]/input_df["total_words"]

	key_features_list = [["length_minutes","mean_faces_detected_in_frame","inaudible_per_word","redacted_per_word"],["num_subjects","total_words","num_inaudible","num_redacted"],["overall_db","mean_flatness","total_turns","mean_face_area"]]
	n_bins_list = [[30, 7, 6, 6],[4, 30, 20, 20],[10, 20, 30, 30]]
	cur_date = date.today().strftime("%m/%d/%Y")

	combined_pdf = PdfPages(os.path.join(output_folder,"all-dists-by-type.pdf"))
	for j in range(len(key_features_list)):
		key_features = key_features_list[j]
		n_bins = n_bins_list[j]

		fig, axs = plt.subplots(figsize=(15,15), nrows=2, ncols=2)
		for i in range(len(key_features)):
			comb_list = [input_df[input_df["interview_type"]=="open"][key_features[i]].tolist(), input_df[input_df["interview_type"]=="psychs"][key_features[i]].tolist()]
			cur_bins = n_bins[i]
			if i < 2:
				cur_ax = axs[0][i]
			else:
				cur_ax = axs[1][i-2]
			cur_ax.hist(comb_list, cur_bins, histtype="bar", stacked=True, orientation="horizontal", label=["open", "psychs"], edgecolor = "black")
			cur_ax.legend()
			cur_ax.set_title(key_features[i])

		fig.suptitle(cur_server + " AVL QC Distributions - stacked histograms by interview type" + "\n" + "(Data as of " + cur_date + ")")
		fig.tight_layout()
		combined_pdf.savefig()
	combined_pdf.close()

	open_only = input_df[input_df["interview_type"]=="open"]
	psychs_only = input_df[input_df["interview_type"]=="psychs"]
	site_list = list(set(input_df["study"].tolist()))
	site_list.sort()
	site_names = [x[-2:] for x in site_list]
	open_n_bins_list = [[15, 7, 6, 6],[2, 20, 20, 15],[10, 10, 15, 25]]

	open_pdf = PdfPages(os.path.join(output_folder,"open-dists-by-site.pdf"))
	for j in range(len(key_features_list)):
		key_features = key_features_list[j]
		n_bins = open_n_bins_list[j]

		fig, axs = plt.subplots(figsize=(15,15), nrows=2, ncols=2)
		for i in range(len(key_features)):
			comb_list = [open_only[open_only["study"]==x][key_features[i]].tolist() for x in site_list]
			cur_bins = n_bins[i]
			if i < 2:
				cur_ax = axs[0][i]
			else:
				cur_ax = axs[1][i-2]
			cur_ax.hist(comb_list, cur_bins, histtype="bar", stacked=True, orientation="horizontal", label=site_names, edgecolor = "black")
			cur_ax.legend()
			cur_ax.set_title("open " + key_features[i])

		fig.suptitle(cur_server + " OPEN interview AVL QC Distributions - stacked histograms by site" + "\n" + "(Data as of " + cur_date + ")")
		fig.tight_layout()
		open_pdf.savefig()
	open_pdf.close()

	psychs_pdf = PdfPages(os.path.join(output_folder,"psychs-dists-by-site.pdf"))
	for j in range(len(key_features_list)):
		key_features = key_features_list[j]
		n_bins = n_bins_list[j]

		fig, axs = plt.subplots(figsize=(15,15), nrows=2, ncols=2)
		for i in range(len(key_features)):
			comb_list = [psychs_only[psychs_only["study"]==x][key_features[i]].tolist() for x in site_list]
			cur_bins = n_bins[i]
			if i < 2:
				cur_ax = axs[0][i]
			else:
				cur_ax = axs[1][i-2]
			cur_ax.hist(comb_list, cur_bins, histtype="bar", stacked=True, orientation="horizontal", label=site_names, edgecolor = "black")
			cur_ax.legend()
			cur_ax.set_title("psychs " + key_features[i])

		fig.suptitle(cur_server + " PSYCHS interview AVL QC Distributions - stacked histograms by site" + "\n" + "(Data as of " + cur_date + ")")
		fig.tight_layout()
		psychs_pdf.savefig()
	psychs_pdf.close()

	return

if __name__ == '__main__':
	# Map command line arguments to function arguments
	run_summary_operation_figs(sys.argv[1], sys.argv[2], sys.argv[3])