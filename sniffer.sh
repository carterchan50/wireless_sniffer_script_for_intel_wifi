#!/bin/bash
capture_bw=0
band=0
ctrl_freq=0
center_freq=0

function usage(){
	echo ""; echo ""; echo "";
	echo "Usage of sniffer enable script for INTEL inside chipset"
	echo "./sniffer.sh CH BW UI"
	echo "CH. 1-13 for 2.4GHz"
	echo "    36-64, 100-140, 149-165 for 5GHz"
	echo ""
	echo "BW. default is HT20, 2.4GHz only 20MHz, 5GHz can choose 80MHz bandwidth"
	echo "\"HT20\", \"VHT80\""
	echo ""
	echo "UI. use wireshark or tshark"
	echo "\"ui\", \"text\""
	echo "text capture will output to \"sniffer_log.pcap\" by defualt"
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
	if [ ${1} == "VHT80" ]; then
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

	if [ ${bnd} -eq 5 ]; then
		freq_offset=$(expr 5 \* $ch)
		ctrl_freq=$(expr $freq_offset + 5000)
		echo "freq: ${ctrl_freq}"
	else
		freq_offset=$(expr 5 \* $ch)
                ctrl_freq=$(expr $freq_offset + 2407)
                echo "freq: ${ctrl_freq}"

	fi
}

function calculate_center_freq(){
	ch=${1}
	top_ch=0
	bottom_ch=0

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
		capture_bw=20
	fi

	low_freq_offset=$(expr 5 \* $bottom_ch)
        low_freq=$(expr $low_freq_offset + 5000)

	high_freq_offset=$(expr 5 \* $top_ch)
        high_freq=$(expr $high_freq_offset + 5000)

	let center_freq=${low_freq}+${high_freq}
	center_freq=$(expr $center_freq / 2)
	echo "center_freq=${center_freq}"

}

check_param ${1} ${2};

sudo modprobe -r iwlmvm
sleep 2
echo "NOTE!!!!! wpa_supplicant will be disabled!!!!!!"
sudo killall wpa_supplicant
sleep 2
sudo modprobe iwlwifi
sleep 2
sudo ifconfig wlp2s0 down
sudo iw wlp2s0 set type monitor
sudo ifconfig wlp2s0 up

calculate_ctrl_freq ${1} ${band}
calculate_center_freq ${1}
echo "capture_bw $capture_bw"

if [ ${capture_bw} -eq 20 ]; then
	sudo iw wlp2s0 set freq ${ctrl_freq} HT20
else
	sudo iw wlp2s0 set freq ${ctrl_freq} 80 ${center_freq}
fi

if [ "$#" -eq 3 ] && [ ${3} == "ui" ]; then
	sudo wireshark
elif [ "$#" -eq 3 ] && [ ${3} == "text" ]; then
	sudo tshark -i wlp2s0 -w sniffer_log.pcap
else
	sudo wireshark
fi


