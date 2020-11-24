#!/bin/bash

# Postfix report
# ====================
# Uses pflogsumm to generate reports from
# mail log files and email a summary.

# NOTE:
# All the configurable paramaters are set
# in report.vars. It's  ideal to copy the
# report.vars  to "lc_report.vars" so the
# the configured  paramaters do  not  get
# overwritten when executing  a  git pull.


# Check argument was given
case "$1" in
	daily)
		r_type="daily" ;;
	weekly)
		r_type="weekly" ;;
	monthly)
		r_type="monthly" ;;
	*)
		printf '\n[ERROR:] Required argument missing, script needs to be called with argument "daily", "weekly" or "monthly" \nEXIT\n'
		exit 0
		;;
esac

# Check if root
if [[ $EUID -ne 0 ]] ; then
	printf '\nThis script must be run as root\nEXIT\n'
	exit
fi

# Source the vars
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
if [[ -e ${current_dir}/lc_report.vars ]] ; then
	# shellcheck source=lc_report.vars
	source "${current_dir}/lc_report.vars"
else
	if [[ -e "${current_dir}/report.vars" ]] ; then
		# shellcheck source=report.vars
		source "${current_dir}/report.vars"
	else
		printf '\n[ERROR:] Cannot find the vars source file\nEXIT\n'
		exit 0
	fi
fi

# Check if pflogsumm is installed
if ! pflogsumm --version > /dev/null ; then
	printf '\n[ERROR:] "pflogsumm" must be installed\nEXIT\n'
	exit 0
fi

# Check if logwatch is installed
((run_logwatch == 1)) && if ! logwatch --version > /dev/null ; then
	printf '\n[ERROR:] "run_logwatch" is set to  "true"\nhowever it does not seem to be installed\nEXIT\n'
	exit 0
fi

# If email_report true check if py script exists
((email_report == 1)) && if ! [ -e "$py_mail" ]; then
	printf '\n[ERROR:] python %s file does not exist however email_report is set to true\nEXIT\n' "$py_mail"
	exit 0
fi

cleanup()
{
	for f in "${tmp_file[@]}" ; do
		rm -f "$f"
	done
}

trap cleanup EXIT

# Temp files for generating the email summary.
tmp_file[0]="$(mktemp /tmp/XXXXXXXXXXX)"
tmp_file[1]="$(mktemp /tmp/XXXXXXXXXXX)"
tmp_file[2]="$(mktemp /tmp/XXXXXXXXXXX)"
tmp_file[3]="$(mktemp /tmp/XXXXXXXXXXX)"

day=()
if [[ $r_type == daily ]] ; then

	# Dates for filenames, regex and report text.
	day[0]="-d"
	day[1]="yesterday"
	date[0]="$(date -d "${day[1]}" "+%Y-%m-%d")" # 2020-01-01
	date[1]="$(date -d "${day[1]}" "+%b %e")" # Jan  1
	logwatch_date="${day[1]^}"
	loop_date=("${date[1]}")
	log_dir="${log_path}/${dir_day}"
	log_smr="${log_dir}/${date[0]}_summary.log" # summary report dest
	((daily_vbs_rpt == 1)) && log_vbs="${log_dir}/${date[0]}_verbose.log" # verbose report dest
	email_extract="Per-Hour Traffic Summary" # for sed
	old_logs="$old_day"

elif [[ $r_type == weekly ]] ; then

	# Dates for filenames, regex and report text.
	date[0]="$(date -d 'last monday' "+%Y-%m-%d")" # 2020-01-01
	date[1]="$(date -d 'last monday' "+%b %e")" # Jan  1
	for d in {0..6} ; do
		loop_date+=("$(date -d "last monday + $d day" "+%b %e")")
	done
	logwatch_date="between $(date -d "${date[0]}" "+%D") and $(date -d "${date[0]} + 6 day" "+%D")"
	log_dir="${log_path}/${dir_week}"
	log_smr="${log_dir}/${date[0]}_summary.log" # summary report dest
	((weekly_vbs_rpt == 1)) && log_vbs="${log_dir}/${date[0]}_verbose.log" # verbose report dest
	email_extract="Per-Hour Traffic Daily Average" # for sed
	old_logs="$old_week"

elif [[ $r_type == monthly ]] ; then

	# Dates for filenames, regex and report text.
	date[0]="$(date -d 'last month' "+%Y-%m-01")" # 2020-01-01
	date[1]="$(date -d 'last month' "+%b")" # Jan
	loop_date=("${date[1]}")
	logwatch_date="between $(date -d "${date[0]}" "+%D") and $(date -d "-$(date +%d) days" "+%D")"
	log_dir="${log_path}/${dir_month}"
	log_smr="${log_dir}/${date[0]}_summary.log" # summary report dest
	((monthly_vbs_rpt == 1)) && log_vbs="${log_dir}/${date[0]//-01}_verbose.log" # verbose report dest
	email_extract="Per-Hour Traffic Daily Average" # for sed
	old_logs="$old_month"

fi

# Postfix log files used to generate reports
mapfile -t mail_logs < <(find "$mail_dir" -type f -iname "${log_name}*" -newermt "${date[0]}" -exec stat '--format=%y %n' {} \; | sort | sed 's,.* /,/,')

# If the report period spans  multiple
# log files extract the relevant dates
# and concate them into one temp file.
if ((${#mail_logs[@]} == 1)) && [[ $r_type == daily ]]; then
	mail_log="${mail_dir}/$log_name"
else
	for f in "${mail_logs[@]}" ; do
		for d in "${loop_date[@]}" ; do # loop per day for weekly report
			[[ $f =~ \.gz ]] && GREP="zgrep" || GREP="grep"
			$GREP -E "^${d} " "$f" >> "${tmp_file[2]}"
		done
	done
	mail_log="${tmp_file[2]}"
fi

# Create dest log dir if does not exist
[[ -d $log_dir ]] || mkdir -p "$log_dir"

# Create report
pflogsumm "${day[@]}" "$mail_log" > "$log_smr"
if [[ -n $log_vbs ]] ; then
	pflogsumm --verbose-msg-detail "${day[@]}" "$mail_log" > "$log_vbs"
fi

# Delete old logs
if ((del_old == 1)) ; then
	old_date="$(date --date="$old_logs days ago" "+%y-%m-%d")"
	if [[ -n $log_dir ]] ; then
	# double check a path exists in $log_dir so not to execute a rm in /
		find "${log_dir}/" -type f ! -newermt "$old_date" -iname "*.log" -exec rm {} \;
		# using the iname for *.log is a safety catch as we are executing rm
	fi
fi

# logwatch amavis report
if ((run_logwatch == 1)) ; then
	printf '\n\n\n' >> "$log_smr"
	logwatch --service amavis --range "$logwatch_date" --detail med >> "$log_smr"
	if [[ -n $log_vbs ]] ; then
		printf '\n\n\n' >> "$log_smr"
		logwatch --service amavis --range "$logwatch_date" --detail high >> "$log_vbs"
	fi
fi


# Create the summary for email ->
if ((email_report == 1)) ; then

	# get the totals
	sed -n "/^Grand Totals/,/${email_extract}/{/${email_extract}/!p}" "$log_smr" > "${tmp_file[0]}"

	# Failed logins count
	login_count="$(grep -Ec 'unknown\[([0-9]{1,3}[\.]){3}[0-9]{1,3}\]: SASL PLAIN authentication failed' "$log_smr")"
	printf '%s Bad Logins\n------------\n' "$login_count" >> "${tmp_file[0]}"

	# If there are failed logins extract them and add to summary.
	((bad_logins == 1)) && if ((login_count > 0)) ; then
		grep -E 'unknown\[([0-9]{1,3}[\.]){3}[0-9]{1,3}\]: SASL PLAIN authentication failed' "$log_smr" >> "${tmp_file[0]}"
	fi

	printf '\n\n' >> "${tmp_file[0]}"

	# Get the reject detail (blocked by rbl lists.)
	msg[0]="message deferral detail"
	msg[1]="message reject detail"

	# Check if there is a 'deferral' entry else extract from 'detail'
	if grep "^${msg_start[0]}$" "$log_smr" ; then
		msg_start="${msg[0]}"
	else
		msg_start="${msg[1]}"
	fi

	sed -n "/^${msg_start}/,/^    cannot find your hostname (total:/p" "$log_smr" >> "${tmp_file[0]}"

	printf '\n\n' >> "${tmp_file[0]}"

	msg=()
	msg[0]="    Recipient address rejected:"
	msg[1]="    Sender address rejected:"

	if grep "^${msg[0]}$" "$log_smr" ; then
		msg_start="${msg[0]}"
	elif grep "^${msg[1]}$" "$log_smr" ; then
		msg_start="${msg[1]}"
	else
		msg_start="message reject warning detail:"
	fi

	sed -n "/^${msg_start}/,/^Warnings/p" "$log_smr" >> "${tmp_file[0]}"

	sed -i '/^Warnings$/d' "${tmp_file[0]}"

	sed -n '/^Fatal Errors:/,/Master daemon messages/p' "$log_smr" >> "${tmp_file[0]}"

	# logwatch amavis report
	if ((run_logwatch == 1)) ; then
		sed -n '/---* Amavisd-new Begin ---*/,/.*[******] Detail/p' "$log_smr" > "${tmp_file[3]}"
		sed -Ei '/.*[******] (Summary|Detail) .*/d' "${tmp_file[3]}"
		grep -E -B2 -A11 '^ Spam Score Percentiles' "$log_smr" >> "${tmp_file[3]}"
		printf '\n\n---------------------- Amavisd-new End -------------------------\n' >> "${tmp_file[3]}"
		printf '\n\n' >> "${tmp_file[0]}"
		cat "${tmp_file[3]}" >> "${tmp_file[0]}"
	fi

	# Create email notofication

	text[0]="$r_type Mail report:\n------------------" # header
	text[1]="   Report period: ${date[0]}" # report date
	text[2]="   Server Name:   $(hostname -f)" # server_name
	text[3]="   Server IP:     $(hostname -I)" # server_ip
	text[4]="   WAN IP:        $(curl ipecho.net/plain ; echo)\n" # wan_ip
	text[5]=" Log files path\n ---------------" # log_header
	text[6]="   Summary log:   $log_smr" # summary log path
	if [[ -n $log_vbs ]] ; then
		text[7]="   Verbose log:   $log_vbs" # verbose log path
	fi

	tmp_txt="$(cat "${tmp_file[0]}")"

	printf '%b\n' "${text[@]}" > "${tmp_file[0]}"
	printf '\n%b\n' "$tmp_txt" >> "${tmp_file[0]}"

	# Check the size of the log dir
	if ((du_check == 1)) ; then
		log_size="$(du -sb "$log_path" | cut -f1)" # log dir size
		du_size_k="$(((du_size / 1024 / 1024)))"
		if ((log_size > du_size_k)) ; then # if bigger then 100MB
			warn="$(awk "BEGIN {printf \"WARNING:       Log dir SIZE:%.2fMB\n\",${log_size}/1024/1024}")"
			sed -i "/   Report Date:/i \   $warn" "${tmp_file[0]}"
		fi
	fi

	# make sure there is internet connection before atempting to send.
	if ((con_check == 1)) ; then
		while true ; do
			if ping -c 1 "$con_domain" > /dev/null ; then
				break
			else
				sleep 10
				continue
			fi
		done
	fi

	# send the email
	python "$py_mail" "$r_type MAIL report" "${tmp_file[0]}"
	wait
fi
