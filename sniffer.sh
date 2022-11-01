#!/bin/bash

# parse options
OPTS=`getopt -o hti:b:c:f:w:o: -l help,text,intf:,band:,channel:,freq:,bandwidth:,output:, -- "$@"`
eval set -- "$OPTS"

CAP_BW=20
BAND=2
CTRL_FREQ=2412
center_freq=2412
CAP_INTF=wlp58s0
CAP_CHANNEL=1
cap_file_path=/root/chenyic/working/sniffer_log
MODE="TEXT"
FREQ_INPUT=false

DATE=$(date +"%Y-%m-%d-%H%M%S")
CAP_FILE_NAME=${DATE}.pcap
cap_eth_file_name=eth_sniffer.pcap


while true; do
        case "$1" in
                -h | --help ) usage; shift ;;
                -t | --text ) MODE="TEXT"; shift ;;
                -i | --intf ) CAP_INTF=$2; shift 2 ;;
                -b | --band ) BAND=$2; shift 2 ;;
                -c | --channel ) CAP_CHANNEL=$2; shift 2 ;;
                -f | --freq ) CTRL_FREQ=$2;FREQ_INPUT=true; shift 2 ;;
                -w | --bandwidth ) CAP_BW=$2; shift 2 ;;
                -o | --output ) CAP_FILE_NAME=$2; shift 2 ;;
                -- ) shift; break ;;
                * ) break ;;
        esac
done


function usage(){
	echo ""; echo ""; echo "";
	echo "Usage of sniffer enable script for INTEL inside chipset"
	echo "./sniffer.sh -i cap_intf -c channel -b band -m cap_mode"
	echo ""
	echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "-f --freq: control_frequency, if you assign the parameter, it doesn't care what are the value of -c and -b"
	echo "it uses the freq to caculate the corresponding band and channel"
        echo ""
	echo "-c --channel: Control channel."
	echo "    1-13 for 2.4GHz"
	echo "    36-64, 100-140, 149-165 for 5GHz"
	echo "	  1-93 for 6GHz"
	echo ""
        echo "-b --band: Capture_Band: default is 2.4GHz, can choose 5GHz or 6GHz"
        echo "2, 5, 6"
	echo ""
	echo "-w --bandwidth: Capture_BW: default is HT20, 2.4GHz only 20MHz, 5GHz/6GHz can choose 80MHz or 160MHz bandwidth"
	echo "20, 80, 160"
	echo ""
	echo "-m --mode: TEXT or UI. use wireshark or tshark"
	echo "\"ui\", \"text\""
	echo "by defualt, it uses tshark to capture."
	exit 0
}

function check_ch(){
	ch=${1}
	match=0
	if [ "${ch}" -gt 0 ] && [ "${ch}" -le 13 ]; then
		echo "ch:${ch} is in 2.4G"
		band=2
	elif [ "${ch}" -ge 36 ] || [ "${ch}" -le 165 ]; then
		for ch_index in 36 40 44 48 52 56 60 64 100 104 108 112 116 120 124 128 132 136 140 149 153 157 161 165
		do
			if [ ${ch} -eq ${ch_index} ]; then
				match=1
			fi
		done

		if [ ${match} -eq 1 ]; then
			echo "ch:${ch} is 5GHz"
			band=5
		else
			echo "ch:${ch} is wrong index" && usage;
		fi
	else
                echo "ch:${ch} is wrong index" && usage;
	fi
}

function check_bw(){
	if [ ${1} == "VHT160" ]; then
                capture_bw=160
        elif [ ${1} == "VHT80" ]; then
		capture_bw=80
	elif [ ${1} == "HT20" ]; then
		capture_bw=20
	else
		echo "use default capture BW:20MHz"
		capture_bw=20
	fi
}

function check_param(){
	[ "$#" -lt 2 ] && echo "The number of parameter is less than 2.  Stop here." && usage;
	check_ch ${1};
	check_bw ${2};
}

function calculate_ctrl_freq(){
	bnd=${2}
	ch=${1}

	if ${FREQ_INPUT}; then
		echo "Has input freq: ${CTRL_FREQ} MHz"
	else
		if [ ${bnd} -eq 5 ]; then
			freq_offset=$(expr 5 \* $ch)
			CTRL_FREQ=$(expr $freq_offset + 5000)
			echo "freq: ${CTRL_FREQ}"
		elif [ ${bnd} -eq 6 ]; then
			freq_offset=$(expr 5 \* $ch)
                        CTRL_FREQ=$(expr $freq_offset + 5950)
			echo "freq: ${CTRL_FREQ}"
		else
			freq_offset=$(expr 5 \* $ch)
			CTRL_FREQ=$(expr $freq_offset + 2407)
			echo "freq: ${CTRL_FREQ}"
		fi

		echo "BAND:${bnd} CH:${ch}: caculated freq: ${CTRL_FREQ} MHz"
	fi
}

function calculate_center_freq(){
	ch=${1}
	top_ch=0
	bottom_ch=0

	if [ ${BAND} -eq 5 ]; then
		if [ ${CAP_BW} -eq 80 ]; then
			if [ ${ch} -ge 36 ] && [ ${ch} -le 48 ]; then
				bottom_ch=36
				top_ch=48
			elif [ ${ch} -ge 52 ] && [ ${ch} -le 64 ]; then
				bottom_ch=52
				top_ch=64
			elif [ ${ch} -ge 100 ] && [ ${ch} -le 112 ]; then
				bottom_ch=100
				top_ch=112
			elif [ ${ch} -ge 116 ] && [ ${ch} -le 128 ]; then
				bottom_ch=116
				top_ch=128
			elif [ ${ch} -ge 149 ] && [ ${ch} -le 161 ]; then
				bottom_ch=149
				top_ch=161
			else
				echo "CH:${ch} Roll back to capture BW 20MHz"
				bottom_ch=${ch}
				top_ch=${ch}
				CAP_BW=20
			fi
		elif [ ${CAP_BW} -eq 160 ]; then
			if [ ${ch} -ge 36 ] && [ ${ch} -le 64 ]; then
				bottom_ch=36
				top_ch=64
			elif [ ${ch} -ge 100 ] && [ ${ch} -le 128 ]; then
				bottom_ch=100
				top_ch=128
			else
				echo "CH:${ch} Roll back to capture BW 20MHz"
				bottom_ch=${ch}
				top_ch=${ch}
				CAP_BW=20
			fi
		else
			bottom_ch=${ch}
			top_ch=${ch}
			CAP_BW=20
		fi
		low_freq_offset=$(expr 5 \* $bottom_ch)
		low_freq=$(expr $low_freq_offset + 5000)
		high_freq_offset=$(expr 5 \* $top_ch)
		high_freq=$(expr $high_freq_offset + 5000)
		
		let center_freq=${low_freq}+${high_freq}
		center_freq=$(expr $center_freq / 2)
	elif [ ${BAND} -eq 6 ]; then
		if [ ${CAP_BW} -eq 80 ]; then
                        if [ ${ch} -ge 1 ] && [ ${ch} -le 13 ]; then
                                bottom_ch=1
                                top_ch=13
                        elif [ ${ch} -ge 17 ] && [ ${ch} -le 29 ]; then
                                bottom_ch=17
                                top_ch=29
                        elif [ ${ch} -ge 33 ] && [ ${ch} -le 45 ]; then
                                bottom_ch=33
                                top_ch=45
                        elif [ ${ch} -ge 49 ] && [ ${ch} -le 61 ]; then
                                bottom_ch=49
                                top_ch=61
                        elif [ ${ch} -ge 65 ] && [ ${ch} -le 77 ]; then
                                bottom_ch=65
                                top_ch=77
			elif [ ${ch} -ge 81 ] && [ ${ch} -le 93 ]; then
                                bottom_ch=81
                                top_ch=93
                        else
                                echo "CH:${ch} Roll back to capture BW 20MHz"
                                bottom_ch=${ch}
                                top_ch=${ch}
                                CAP_BW=20
                        fi
                elif [ ${CAP_BW} -eq 160 ]; then
                        if [ ${ch} -ge 1 ] && [ ${ch} -le 29 ]; then
                                bottom_ch=1
                                top_ch=29
                        elif [ ${ch} -ge 33 ] && [ ${ch} -le 61 ]; then
                                bottom_ch=33
                                top_ch=61
			elif [ ${ch} -ge 65 ] && [ ${ch} -le 93 ]; then
                                bottom_ch=65
                                top_ch=93
                        else
                                echo "CH:${ch} Roll back to capture BW 20MHz"
                                bottom_ch=${ch}
                                top_ch=${ch}
                                CAP_BW=20
                        fi
                else
                        bottom_ch=${ch}
                        top_ch=${ch}
                        CAP_BW=20
                fi
                low_freq_offset=$(expr 5 \* $bottom_ch)
                low_freq=$(expr $low_freq_offset + 5950)
                high_freq_offset=$(expr 5 \* $top_ch)
                high_freq=$(expr $high_freq_offset + 5950)

                let center_freq=${low_freq}+${high_freq}
                center_freq=$(expr $center_freq / 2)
	else
		bottom_ch=${ch}
		top_ch=${ch}
		CAP_BW=20
		
		low_freq_offset=$(expr 5 \* $bottom_ch)
		low_freq=$(expr $low_freq_offset + 2407)
		high_freq_offset=$(expr 5 \* $top_ch)
		high_freq=$(expr $high_freq_offset + 2407)
		let center_freq=${low_freq}+${high_freq}
		center_freq=$(expr $center_freq / 2)
	fi

	echo "center_freq=${center_freq}"
}


function update_ch_by_freq(){
        if [ ${BAND} -eq 6 ]; then
                CAP_CHANNEL=$(expr $CTRL_FREQ - 5950)
		CAP_CHANNEL=$(expr $CAP_CHANNEL \/ 5)
                echo "CAP_CHANNEL: ${CAP_CHANNEL}"
	elif [ ${BAND} -eq 5 ]; then
		CAP_CHANNEL=$(expr $CTRL_FREQ - 5000)
                CAP_CHANNEL=$(expr $CAP_CHANNEL \/ 5)
		echo "CAP_CHANNEL: ${CAP_CHANNEL}"
        else
		CAP_CHANNEL=$(expr $CTRL_FREQ - 2407)
                CAP_CHANNEL=$(expr $CAP_CHANNEL \/ 5)
		echo "CAP_CHANNEL: ${CAP_CHANNEL}"

        fi
}

function update_ch_and_band_by_freq(){
	if ${FREQ_INPUT}; then
		if [ ${CTRL_FREQ} -ge 5955 ]; then
			BAND=6
		elif [ ${CTRL_FREQ} -ge 5180 ]; then
			BAND=5
		else
			BAND=2
		fi
		echo "Freq:${CTRL_FREQ}, band is:${BAND}G"
		update_ch_by_freq
	else
		echo "no freq input, use band and ch to caculate it."
	fi
}

while true; do
        case "$1" in
                -h | --help ) usage; shift ;;
		-t | --text ) MODE="TEXT"; shift ;;
                -i | --intf ) CAP_INTF=$2; shift 2 ;;
		-b | --band ) BAND=$2; shift 2 ;;
		-c | --channel ) CAP_CHANNEL=$2; shift 2 ;;
		-f | --freq ) CTRL_FREQ=$2;FREQ_INPUT=true; shift 2 ;;
		-w | --bandwidth ) CAP_BW=$2; shift 2 ;;
		-o | --output ) CAP_FILE_NAME=$2; shift 2 ;;
                -- ) shift; break ;;
                * ) break ;;
        esac
done

update_ch_and_band_by_freq
echo "BAND:${BAND} CAP_CHANNEL: ${CAP_CHANNEL}"
#check_param ${1} ${2};

echo "unload iwlwifi"
sudo modprobe -r iwlmvm
sudo modprobe -r iwlwifi
sleep 2

echo "NOTE!!!!! wpa_supplicant will be disabled!!!!!!"
sudo killall wpa_supplicant
sleep 2

echo "load iwlwifi"
sudo modprobe iwlwifi amsdu_size=3
sleep 2

echo "config wifi to monitor mode"
sudo ifconfig $CAP_INTF down
sudo iw $CAP_INTF set type monitor
sudo ifconfig $CAP_INTF up

calculate_ctrl_freq ${CAP_CHANNEL} ${BAND}
calculate_center_freq ${CAP_CHANNEL}
echo "capture_bw $CAP_BW"

if [ ${CAP_BW} -eq 20 ]; then
	sudo iw $CAP_INTF set freq ${CTRL_FREQ} HT20
elif [ ${CAP_BW} -eq 80 ]; then
	sudo iw $CAP_INTF set freq ${CTRL_FREQ} 80 ${center_freq}
else
        sudo iw $CAP_INTF set freq ${CTRL_FREQ} 160 ${center_freq}
fi

echo "check wifi status"
iw dev

echo "launch capturing tool"
if [ ${MODE} == "UI" ]; then
	sudo wireshark
elif [ ${MODE} == "TEXT" ]; then
	touch ${cap_file_path}${CAP_FILE_NAME}
	chmod o=rw ${cap_file_path}${CAP_FILE_NAME}
	sudo tshark -i ${CAP_INTF} -w ${cap_file_path}${CAP_FILE_NAME}
else
	sudo wireshark
fi


