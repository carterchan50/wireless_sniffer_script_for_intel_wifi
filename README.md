# wireless_sniffer_script_for_intel_wifi
a script let you can capture wireless sniffer packet by intel wifi


Prerequistes:
  1) Wireshark installed
  2) Tshark installed
  3) Intel Wifi Chipset inside
    >> the kernel supporting list, please reference the link:
      https://wireless.wiki.kernel.org/en/users/drivers/iwlwifi
      
      the actual capturing ability depends on the wifi chipset itself.
      
Test Environment:
  1) Ubuntu 18.04.1, Kernel: 4.15-29
  2) Intel 8265
  
 Command examples:(in case you type wrong, there will be usage shows up)
 
1) capture by wireshark
 ./sniffer.sh 11 HT20
 ./sniffer.sh 36 VHT80
 
2) capture by tshark
 ./sniffer.sh 11 HT20 text
 ./sniffer.sh 36 HT20 text
